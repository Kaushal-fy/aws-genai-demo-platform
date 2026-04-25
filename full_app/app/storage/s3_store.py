import os
import json
import uuid
from datetime import datetime


class S3Store:

    def __init__(self, base_path="local_s3"):
        self.base_path = base_path
        os.makedirs(self.base_path, exist_ok=True)

    def upload_demo(self, data: dict):

        key = f"demo-{uuid.uuid4()}.json"
        timestamp = datetime.utcnow().isoformat()

        payload = {
            "timestamp": timestamp,
            "data": data
        }

        file_path = os.path.join(self.base_path, key)

        with open(file_path, "w") as f:
            json.dump(payload, f, indent=2)

        return {
            "s3_key": key,
            "location": file_path
        }
