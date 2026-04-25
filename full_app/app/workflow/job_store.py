import uuid
from datetime import datetime


class JobStore:

    def __init__(self):
        self.jobs = {}

    def create_job(self, payload: dict):

        job_id = str(uuid.uuid4())

        self.jobs[job_id] = {
            "job_id": job_id,
            "status": "PENDING",
            "payload": payload,
            "result": None,
            "created_at": datetime.utcnow().isoformat()
        }

        return job_id

    def update_job(self, job_id: str, status: str, result=None):

        if job_id not in self.jobs:
            return None

        self.jobs[job_id]["status"] = status
        self.jobs[job_id]["result"] = result

        return self.jobs[job_id]

    def get_job(self, job_id: str):

        return self.jobs.get(job_id)
