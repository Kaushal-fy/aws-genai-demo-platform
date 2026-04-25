from app.workflow.job_store import JobStore
from app.workflow.job_queue import JobQueue
from app.workflow.worker import Worker

job_store = JobStore()
job_queue = JobQueue()

worker = Worker(job_store, job_queue)

worker.process_jobs()
