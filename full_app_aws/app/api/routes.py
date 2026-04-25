from fastapi import APIRouter
from pydantic import BaseModel
from app.workflow.job_store import JobStore
from app.workflow.job_queue import JobQueue


router = APIRouter()

job_store = JobStore()
job_queue = JobQueue()


class DemoRequest(BaseModel):
    use_case: str
    complexity: str


@router.post("/generate-demo-async")
def generate_demo(request: DemoRequest):

    job_id = job_store.create_job({
        "use_case": request.use_case,
        "complexity": request.complexity
    })

    job_queue.push(job_id)

    return {
        "job_id": job_id,
        "status": "QUEUED"
    }


@router.get("/job/{job_id}")
def get_job(job_id: str):

    return job_store.get_job(job_id)
