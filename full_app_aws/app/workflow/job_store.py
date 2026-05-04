import os
import uuid
from decimal import Decimal
from datetime import datetime

import boto3


class JobStore:

    def __init__(self, table_name=None):
        resolved_table_name = table_name or os.getenv("GENAI_JOBS_TABLE")
        region_name = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")

        if not resolved_table_name:
            raise ValueError("GENAI_JOBS_TABLE environment variable is required")

        if not region_name:
            raise ValueError("AWS_REGION or AWS_DEFAULT_REGION environment variable is required")

        self.table_name = resolved_table_name
        self.table = boto3.resource("dynamodb", region_name=region_name).Table(self.table_name)

    def _normalize(self, value):
        if isinstance(value, list):
            return [self._normalize(item) for item in value]

        if isinstance(value, dict):
            return {
                key: self._normalize(item)
                for key, item in value.items()
            }

        if isinstance(value, Decimal):
            if value % 1 == 0:
                return int(value)

            return float(value)

        return value

    def create_job(self, payload: dict):

        job_id = str(uuid.uuid4())

        item = {
            "job_id": job_id,
            "status": "PENDING",
            "payload": payload,
            "result": None,
            "created_at": datetime.utcnow().isoformat()
        }

        self.table.put_item(Item=item)

        return job_id

    def update_job(self, job_id: str, status: str, result=None):
        response = self.table.update_item(
            Key={"job_id": job_id},
            UpdateExpression="SET #status = :status, #result = :result",
            ExpressionAttributeNames={
                "#status": "status",
                "#result": "result"
            },
            ExpressionAttributeValues={
                ":status": status,
                ":result": result
            },
            ConditionExpression="attribute_exists(job_id)",
            ReturnValues="ALL_NEW"
        )

        return self._normalize(response["Attributes"])

    def get_job(self, job_id: str):
        response = self.table.get_item(Key={"job_id": job_id})
        item = response.get("Item")

        if not item:
            return None

        return self._normalize(item)
