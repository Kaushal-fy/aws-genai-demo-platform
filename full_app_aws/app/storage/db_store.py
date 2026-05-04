import os
from datetime import datetime
from decimal import Decimal

import boto3


class DynamoDBStore:

    def __init__(self):
        table_name = os.getenv("GENAI_METADATA_TABLE")
        region_name = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")

        self._memory_table = {}
        self.table = None

        if table_name and region_name:
            self.table = boto3.resource("dynamodb", region_name=region_name).Table(table_name)

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

    def save_metadata(self, demo_data: dict):

        demo_id = demo_data["demo_id"]
        storage = demo_data.get("storage", {})
        s3_storage = storage.get("s3", {})

        record = {
            "demo_id": demo_id,
            "status": demo_data["status"],
            "use_case": demo_data.get("use_case", "unknown"),
            "complexity": demo_data.get("complexity", "unknown"),
            "created_at": datetime.utcnow().isoformat(),
            "components_count": len(demo_data.get("components", [])),
            "logs_count": len(demo_data.get("logs", [])),
            "insights_count": len(demo_data.get("insights", [])),
            "artifact_bucket": s3_storage.get("bucket"),
            "artifact_key": s3_storage.get("s3_key")
        }

        if self.table is not None:
            self.table.put_item(Item=record)
        else:
            self._memory_table[demo_id] = record

        return record

    def get_metadata(self, demo_id: str):
        if self.table is None:
            return self._memory_table.get(demo_id)

        response = self.table.get_item(Key={"demo_id": demo_id})
        item = response.get("Item")

        if not item:
            return None

        return self._normalize(item)
