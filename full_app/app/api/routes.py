from fastapi import APIRouter
from pydantic import BaseModel
from app.services.demo_service import DemoService
from app.core.observability import start_trace, log


router = APIRouter()
service = DemoService()


class DemoRequest(BaseModel):
    use_case: str
    complexity: str


@router.post("/generate-demo")
def generate_demo(request: DemoRequest):

    trace_id = start_trace()

    log("api_request_start", {
        "trace_id": trace_id
    })

    response = service.create_demo(
        request.use_case,
        request.complexity
    )

    log("api_request_end", {
        "trace_id": trace_id,
        "demo_id": response["demo_id"]
    })

    return response
