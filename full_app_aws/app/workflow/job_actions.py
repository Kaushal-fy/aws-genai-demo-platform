from app.workflow.job_queue import JobQueue
from app.workflow.job_store import JobStore


job_store = JobStore()
job_queue = JobQueue()


def submit_async_job(use_case: str, complexity: str):
    job_id = job_store.create_job({
        "use_case": use_case,
        "complexity": complexity
    })

    job_queue.push(job_id)

    return {
        "job_id": job_id,
        "status": "QUEUED"
    }


def get_async_job(job_id: str):
    return job_store.get_job(job_id)