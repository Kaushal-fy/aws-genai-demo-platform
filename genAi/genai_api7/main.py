# pip install fastapi uvicorn boto3
# uvicorn main:app --reload --host 0.0.0.0 --port 8000
# curl -X POST "http://localhost:8000/chat" -H "Content-Type: application/json" -d '{"prompt": "Explain Kubernetes in 3 bullet points"}'


import time
import uuid
import boto3
import botocore
import json
import re
from fastapi import FastAPI
from pydantic import BaseModel


app = FastAPI()
client = boto3.client("bedrock-runtime", region_name="us-east-1")


METRICS = {
    "total_requests": 0,
    "model_usage": {
        "sonnet": 0,
        "haiku": 0
    },
    "failures": 0,
    "repair_used": 0,
    "latency": []
}


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

Return ONLY valid JSON in this format:

{{
  "summary": "short explanation",
  "key_points": ["point1", "point2", "point3"]
}}

Rules:
- No extra text
- No markdown
- Only valid JSON

User question:
{user_input}
"""

# -------------------------
# Extract Json
# -------------------------

def extract_json(text: str):
    try:
        return json.loads(text)
    except:
        pass

    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except:
            pass

    return None
    

#---------------------------------
# Json Validator
#---------------------------------

def validate_json_output(text: str):

    try:
        parsed = json.loads(text)

        # basic schema enforcement
        if "summary" not in parsed:
            raise ValueError("Missing summary")

        if "key_points" not in parsed:
            raise ValueError("Missing key_points")

        return parsed

    except Exception:
        return {
            "summary": "Failed to parse model output",
            "key_points": []
        }

#---------------------------------
# Parse with retry and repair Json
#---------------------------------

def parse_with_retry(raw_text: str, model_id: str, messages, config, retries=1):

    repair_model = MODEL_MAP["sonnet"]

    parsed = extract_json(raw_text)
    if parsed:
        return validate_json_output(json.dumps(parsed))
        
    METRICS["repair_used"] += 1

    # retry with stricter instruction
    repair_prompt = f"""
Fix this and return ONLY valid JSON:

{raw_text}
"""

    for _ in range(retries):
        response = client.converse(
            modelId=repair_model,
            messages=[
                {"role": "user", "content": [{"text": repair_prompt}]}
            ],
            inferenceConfig={
                "maxTokens": 200,
                "temperature": 0
            }
        )

        new_text = response["output"]["message"]["content"][0]["text"]
        parsed = extract_json(new_text)

        if parsed:
            return validate_json_output(json.dumps(parsed))
            
        # if repair triggered    
        METRICS["repair_used"] += 1 

    return None

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

    METRICS["total_requests"] += 1
    

    request_id = str(uuid.uuid4())
    start = time.time()

    model_type = route_intent(req.prompt)
    model_id = MODEL_MAP[model_type]

    METRICS["model_usage"][model_type] += 1

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

    raw_text = response["output"]["message"]["content"][0]["text"]

    
    parsed_output = parse_with_retry(
        raw_text,
        model_id,
        messages=None,
        config=None
    )

    if not parsed_output:
        METRICS["failures"] += 1
        parsed_output = {
            "summary": "Failed to generate valid JSON",
            "key_points": []
        }
        
    
    latency = time.time() - start

    METRICS["latency"].append(latency) 

    print(f"[{request_id}] model={model_type} latency={latency:.2f}s prompt={req.prompt}")

    return {
        "request_id": request_id,
        "latency": latency,
        "input": req.prompt,
        "model": model_type,
        "response": parsed_output
    }
    
@app.get("/metrics")
def get_metrics():

    avg_latency = (
        sum(METRICS["latency"]) / len(METRICS["latency"])
        if METRICS["latency"] else 0
    )

    return {
        "total_requests": METRICS["total_requests"],
        "model_usage": METRICS["model_usage"],
        "failures": METRICS["failures"],
        "repair_used": METRICS["repair_used"],
        "avg_latency": round(avg_latency, 2)
    }
