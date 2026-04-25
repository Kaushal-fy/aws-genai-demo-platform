import uuid
from app.core.generator import DemoGenerator


class DemoService:

    def __init__(self):
        self.generator = DemoGenerator()

    def create_demo(self, use_case: str, complexity: str):

        result = self.generator.generate(use_case, complexity)

        return {
            "demo_id": str(uuid.uuid4()),
            "status": "generated",
            **result
        }
