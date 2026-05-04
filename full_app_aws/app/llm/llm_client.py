import json
import os
import random

import boto3
from app.llm.prompt_templates import PromptTemplates


class LLMClient:

    def __init__(self):
        self.region_name = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
        self.model_id = os.getenv("BEDROCK_MODEL_ID") or os.getenv("GENAI_BEDROCK_MODEL_ID")
        self.use_bedrock = (os.getenv("GENAI_USE_BEDROCK") or "false").lower() == "true"

        self.client = None

        if self.use_bedrock and self.region_name and self.model_id:
            self.client = boto3.client("bedrock-runtime", region_name=self.region_name)

    def call_model(self, use_case: str, complexity: str):

        prompt = PromptTemplates.demo_generation_prompt(
            use_case,
            complexity
        )

        if self.client is not None:
            request_body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1200,
                "temperature": 0.2,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": prompt
                            }
                        ]
                    }
                ]
            }

            response = self.client.invoke_model(
                modelId=self.model_id,
                contentType="application/json",
                accept="application/json",
                body=json.dumps(request_body)
            )

            payload = json.loads(response["body"].read())
            content = payload.get("content", [])
            text_blocks = [
                block.get("text", "")
                for block in content
                if block.get("type") == "text"
            ]

            raw_text = "\n".join(text_blocks).strip()

            if not raw_text:
                raise ValueError("Bedrock response did not contain any text output")

            return json.loads(raw_text)

        # -----------------------------
        # MOCKED LLM RESPONSE (Bedrock placeholder)
        # -----------------------------

        base_response = {
            "components": [
                "API Gateway",
                "Auth Service",
                "Payment Service",
                "Database"
            ],
            "logs": [
                f"{use_case}: request received",
                f"{use_case}: processing started",
                f"{use_case}: timeout in service"
            ],
            "insights": [
                "Increased latency in downstream service",
                "Retry mechanism triggered"
            ]
        }

        # simulate model variability
        if complexity == "high":
            base_response["logs"].append("cascade failure detected")
            base_response["insights"].append("system-wide degradation observed")

        if random.random() > 0.7:
            base_response["insights"].append("unusual traffic spike detected")

        return base_response
