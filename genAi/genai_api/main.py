

from fastapi import FastAPI
from pydantic import BaseModel
import boto3

app = FastAPI()

client = boto3.client("bedrock-runtime", region_name="us-east-1")


# Request schema
class ChatRequest(BaseModel):
    prompt: str


@app.post("/chat")
def chat(req: ChatRequest):

    response = client.converse(
        modelId="global.anthropic.claude-sonnet-4-20250514-v1:0",
        messages=[
            {
                "role": "user",
                "content": [
                    {"text": req.prompt}
                ]
            }
        ],
        inferenceConfig={
            "maxTokens": 300,
            "temperature": 0.5
        }
    )

    return {
        "response": response["output"]["message"]["content"][0]["text"]
    }
