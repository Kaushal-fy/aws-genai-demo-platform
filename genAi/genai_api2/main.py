

from fastapi import FastAPI
from pydantic import BaseModel
import boto3
import time
import uuid

app = FastAPI()

client = boto3.client("bedrock-runtime", region_name="us-east-1")


# Request schema
class ChatRequest(BaseModel):
    prompt: str


@app.post("/chat")
def chat(req: ChatRequest):

    request_id = str(uuid.uuid4())
    start = time.time()
    
    prompt = build_prompt(req.prompt)
    
    response = client.converse(
        modelId="global.anthropic.claude-sonnet-4-20250514-v1:0",
        messages=[
            {
                "role": "user",
                "content": [
                    {"text": prompt}
                ]
            }
        ],
        inferenceConfig={
            "maxTokens": 300,
            "temperature": 0.5
        }
    )

    output = response["output"]["message"]["content"][0]["text"]
    
    latency = time.time() - start
    
    print(f"[{request_id}] latency={latency:.2f}s prompt={req.prompt}")


    return {
        "request_id": request_id,
        "latency": latency,
        "input": req.prompt,
        "response": output 
    }
    
def build_prompt(user_input: str) -> str:
    return f"""
You are a DevOps and AWS expert assistant.

Rules:
- Be concise
- Be technically accurate
- If asked for explanation, use bullet points
- Avoid unnecessary text

User question:
{user_input}
"""
