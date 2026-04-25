from fastapi import APIRouter
from pydantic import BaseModel
from app.services.demo_service import DemoService


router = APIRouter()
service = DemoService()


class DemoRequest(BaseModel):
    use_case: str
    complexity: str


@router.post("/generate-demo")
def generate_demo(request: DemoRequest):

    return service.create_demo(
        request.use_case,
        request.complexity
    )
