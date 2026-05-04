from fastapi import APIRouter
from pydantic import BaseModel
from app.workflow.job_actions import get_async_job, submit_async_job


router = APIRouter()


class DemoRequest(BaseModel):
    use_case: str
    complexity: str


@router.post("/generate-demo-async")
def generate_demo(request: DemoRequest):
    return submit_async_job(request.use_case, request.complexity)


@router.get("/job/{job_id}")
def get_job(job_id: str):
    return get_async_job(job_id)
