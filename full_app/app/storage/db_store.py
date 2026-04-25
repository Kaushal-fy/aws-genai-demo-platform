import uuid
from datetime import datetime


class DynamoDBStore:

    def __init__(self):
        self.table = {}  # in-memory simulation

    def save_metadata(self, demo_data: dict):

        demo_id = demo_data["demo_id"]

        record = {
            "demo_id": demo_id,
            "status": demo_data["status"],
            "created_at": datetime.utcnow().isoformat(),
            "components_count": len(demo_data.get("components", [])),
            "logs_count": len(demo_data.get("logs", [])),
            "insights_count": len(demo_data.get("insights", []))
        }

        self.table[demo_id] = record

        return record

    def get_metadata(self, demo_id: str):
        return self.table.get(demo_id)
