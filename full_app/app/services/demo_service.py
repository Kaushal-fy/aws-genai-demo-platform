from app.core.generator import DemoGenerator
from app.core.observability import log, time_it, start_trace
import uuid


class DemoService:

    def __init__(self):
        self.generator = DemoGenerator()

    @time_it
    def create_demo(self, use_case: str, complexity: str):

        trace_id = start_trace()

        log("request_received", {
            "use_case": use_case,
            "complexity": complexity
        })

        result = self.generator.generate(use_case, complexity)

        response = {
            "demo_id": str(uuid.uuid4()),
            "status": "generated",
            **result
        }

        log("response_generated", {
            "demo_id": response["demo_id"]
        })

        return response
