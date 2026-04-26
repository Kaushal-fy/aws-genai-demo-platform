from app.core.generator import DemoGenerator
from app.core.observability import log, time_it, start_trace
from app.storage.s3_store import S3Store
from app.storage.db_store import DynamoDBStore
import uuid
import os


class DemoService:

    def __init__(self):
        self.generator = DemoGenerator()
        bucket_name = os.getenv("GENAI_S3_BUCKET")

        if not bucket_name:
            raise ValueError("GENAI_S3_BUCKET environment variable is required")

        self.s3 = S3Store(bucket_name=bucket_name)
        self.db = DynamoDBStore()

    @time_it
    def create_demo(self, use_case: str, complexity: str):

        trace_id = start_trace()

        log("request_received", {
            "use_case": use_case,
            "complexity": complexity
        })

        # 1. Generate demo
        result = self.generator.generate(use_case, complexity)

        demo_id = str(uuid.uuid4())

        response = {
            "demo_id": demo_id,
            "status": "generated",
            **result
        }

        # 2. Store full payload in "S3"
        s3_result = self.s3.upload_demo(response)

        # 3. Store metadata in "DynamoDB"
        db_record = self.db.save_metadata(response)

        log("persistence_complete", {
            "demo_id": demo_id,
            "s3_key": s3_result["s3_key"]
        })

        return {
            **response,
            "storage": {
                "s3": s3_result,
                "db": db_record
            }
        }
