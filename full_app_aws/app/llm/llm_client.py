import random
import json
from app.llm.prompt_templates import PromptTemplates


class LLMClient:

    def __init__(self):
        pass

    def call_model(self, use_case: str, complexity: str):

        prompt = PromptTemplates.demo_generation_prompt(
            use_case,
            complexity
        )

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
