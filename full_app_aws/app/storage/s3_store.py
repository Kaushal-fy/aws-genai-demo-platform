import boto3
import json
import uuid
from datetime import datetime


class S3Store:

    def __init__(self, bucket_name):
        self.bucket = bucket_name
        self.client = boto3.client("s3")

    def upload_demo(self, data: dict):

        key = f"demo-{uuid.uuid4()}.json"

        payload = {
            "timestamp": datetime.utcnow().isoformat(),
            "data": data
        }

        self.client.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=json.dumps(payload),
            ContentType="application/json"
        )

        return {
            "s3_key": key,
            "bucket": self.bucket
        }
