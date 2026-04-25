import json


class ResponseParser:

    @staticmethod
    def validate(response: dict):

        required_keys = ["components", "logs", "insights"]

        for key in required_keys:
            if key not in response:
                raise ValueError(f"Missing key: {key}")

        return response

    @staticmethod
    def repair(response):

        # fallback safety layer (future Bedrock failure handling)
        if not isinstance(response, dict):
            return {
                "components": [],
                "logs": ["invalid response"],
                "insights": ["repair triggered"]
            }

        return response
