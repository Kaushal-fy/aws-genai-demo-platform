import json
import os
import uuid
from datetime import datetime


class JobStore:

    def __init__(self, file_path="jobs.json"):
        self.file_path = file_path

        if not os.path.exists(self.file_path):
            with open(self.file_path, "w") as f:
                json.dump({}, f)

    def _read(self):
        with open(self.file_path, "r") as f:
            return json.load(f)

    def _write(self, data):
        with open(self.file_path, "w") as f:
            json.dump(data, f, indent=2)

    def create_job(self, payload: dict):

        jobs = self._read()

        job_id = str(uuid.uuid4())

        jobs[job_id] = {
            "job_id": job_id,
            "status": "PENDING",
            "payload": payload,
            "result": None,
            "created_at": datetime.utcnow().isoformat()
        }

        self._write(jobs)

        return job_id

    def update_job(self, job_id: str, status: str, result=None):

        jobs = self._read()

        if job_id not in jobs:
            return None

        jobs[job_id]["status"] = status
        jobs[job_id]["result"] = result

        self._write(jobs)

        return jobs[job_id]

    def get_job(self, job_id: str):

        jobs = self._read()
        return jobs.get(job_id)
