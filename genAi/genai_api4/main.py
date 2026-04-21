# pip install fastapi uvicorn boto3
# uvicorn main:app --reload --host 0.0.0.0 --port 8000

import time
import uuid
import boto3
import botocore
from fastapi import FastAPI
from pydantic import BaseModel


app = FastAPI()
client = boto3.client("bedrock-runtime", region_name="us-east-1")


# -------------------------
# Retry Layer
# -------------------------
def invoke_with_retry(model_id, messages, inference_config, retries=2):

    for attempt in range(retries + 1):
        try:
            return client.converse(
                modelId=model_id,
                messages=messages,
                inferenceConfig=inference_config
            )

        except botocore.exceptions.ClientError as e:
            if attempt == retries:
                raise e

            time.sleep(0.5 * (attempt + 1))


# -------------------------
# Fallback Layer
# -------------------------
def safe_invoke(model_id, fallback_id, messages, config):

    try:
        return invoke_with_retry(model_id, messages, config)

    except Exception as e:
        print("Primary model failed, switching fallback...")
        return invoke_with_retry(fallback_id, messages, config)


# -------------------------
# Prompt Builder
# -------------------------
def build_prompt(user_input: str) -> str:
    return f"""
You are a DevOps and AWS expert assistant.

Rules:
- Be concise
- Be technically accurate
- Use bullet points when explaining
- Avoid unnecessary text

User question:
{user_input}
"""


# -------------------------
# Router (FIXED + SAFE PARSING)
# -------------------------
def route_intent(prompt: str) -> str:

    router_prompt = f"""
Return ONLY one word: haiku or sonnet.

Rules:
- haiku → simple questions, greetings, short answers
- sonnet → explanations, reasoning, structured output

Input:
{prompt}
"""

    response = client.converse(
        modelId="global.anthropic.claude-haiku-4-5-20251001-v1:0",
        messages=[
            {
                "role": "user",
                "content": [{"text": router_prompt}]
            }
        ],
        inferenceConfig={
            "maxTokens": 10,
            "temperature": 0
        }
    )

    decision = response["output"]["message"]["content"][0]["text"]
    decision = decision.strip().lower().replace(".", "")

    print("ROUTER OUTPUT:", repr(decision))

    if "haiku" in decision:
        return "haiku"

    return "sonnet"


# -------------------------
# Model Map (FIXED)
# -------------------------
MODEL_MAP = {
    "sonnet": "global.anthropic.claude-sonnet-4-20250514-v1:0",
    "haiku": "global.anthropic.claude-haiku-4-5-20251001-v1:0"
}


# -------------------------
# Validation Layer
# -------------------------
def validate_output(text: str) -> str:
    if not text or len(text.strip()) == 0:
        return "Empty response from model."

    if len(text) < 5:
        return "Response too short or invalid."

    return text


# -------------------------
# Request Schema
# -------------------------
class ChatRequest(BaseModel):
    prompt: str


# -------------------------
# API Endpoint
# -------------------------
@app.post("/chat")
def chat(req: ChatRequest):

    request_id = str(uuid.uuid4())
    start = time.time()

    model_type = route_intent(req.prompt)
    model_id = MODEL_MAP[model_type]

    final_prompt = build_prompt(req.prompt)

    response = safe_invoke(
        model_id=model_id,
        fallback_id=MODEL_MAP["haiku"],
        messages=[
            {
                "role": "user",
                "content": [{"text": final_prompt}]
            }
        ],
        config={
            "maxTokens": 300,
            "temperature": 0.5
        }
    )

    output = response["output"]["message"]["content"][0]["text"]
    output = validate_output(output)

    latency = time.time() - start

    print(f"[{request_id}] model={model_type} latency={latency:.2f}s prompt={req.prompt}")

    return {
        "request_id": request_id,
        "latency": latency,
        "input": req.prompt,
        "model": model_type,
        "response": output
    }
