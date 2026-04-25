import time
from app.services.demo_service import DemoService
from app.core.observability import log


class Worker:

    def __init__(self, job_store, job_queue):

        self.job_store = job_store
        self.job_queue = job_queue
        self.service = DemoService()

    def process_jobs(self):

        while True:

            job_id = self.job_queue.pop()

            if not job_id:
                time.sleep(1)
                continue

            job = self.job_store.get_job(job_id)

            if not job:
                continue

            log("worker_start", {"job_id": job_id})

            self.job_store.update_job(job_id, "RUNNING")

            payload = job["payload"]

            result = self.service.create_demo(
                payload["use_case"],
                payload["complexity"]
            )

            self.job_store.update_job(
                job_id,
                "COMPLETED",
                result
            )

            log("worker_complete", {"job_id": job_id})
