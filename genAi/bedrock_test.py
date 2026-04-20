# aws bedrock list-inference-profiles --region us-east-1

import boto3

client = boto3.client("bedrock-runtime", region_name="us-east-1")

response = client.converse(
    modelId="global.anthropic.claude-sonnet-4-20250514-v1:0",
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "text": "Explain Kubernetes in 3 bullet points"
                }
            ]
        }
    ],
    inferenceConfig={
        "maxTokens": 300,
        "temperature": 0.5
    }
)

print(response["output"]["message"]["content"][0]["text"])
