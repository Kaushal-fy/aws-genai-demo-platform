import os

import boto3
import json
import uuid
from datetime import datetime


class S3Store:

    def __init__(self, bucket_name):
        region_name = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")

        if not region_name:
            raise ValueError("AWS_REGION or AWS_DEFAULT_REGION environment variable is required")

        self.bucket = bucket_name
        self.client = boto3.client("s3", region_name=region_name)

    def upload_demo(self, data: dict):

        key = f"artifacts/demo-{uuid.uuid4()}.json"

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
