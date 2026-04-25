from app.llm.llm_client import LLMClient
from app.llm.response_parser import ResponseParser
from app.core.observability import log


class DemoGenerator:

    def __init__(self):
        self.llm = LLMClient()
        self.parser = ResponseParser()

    def generate(self, use_case: str, complexity: str):

        log("llm_request_start", {
            "use_case": use_case,
            "complexity": complexity
        })

        raw_response = self.llm.call_model(use_case, complexity)

        validated = self.parser.validate(raw_response)

        log("llm_request_complete", {
            "components": len(validated["components"])
        })

        return validated
