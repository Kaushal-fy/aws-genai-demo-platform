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

            message = self.job_queue.pop()

            if not message:
                time.sleep(1)
                continue

            job_id = message["job_id"]
            receipt_handle = message["receipt_handle"]

            job = self.job_store.get_job(job_id)

            if not job:
                # Drop stale queue message with no matching job record.
                self.job_queue.ack(receipt_handle)
                continue

            try:
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

                self.job_queue.ack(receipt_handle)
                log("worker_complete", {"job_id": job_id})
            except Exception as exc:
                self.job_store.update_job(
                    job_id,
                    "FAILED",
                    {"error": str(exc)}
                )

                # Leave message unacked so SQS can redeliver after visibility timeout.
                log("worker_error", {"job_id": job_id, "error": str(exc)})
                time.sleep(1)
