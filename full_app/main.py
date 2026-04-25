from fastapi import FastAPI
from pydantic import BaseModel
import uuid
import random
from typing import List

app = FastAPI()


# -------- Request Model --------
class DemoRequest(BaseModel):
    use_case: str
    complexity: str


# -------- Response Model --------
class DemoResponse(BaseModel):
    demo_id: str
    status: str
    components: List[str]
    logs: List[str]
    insights: List[str]


# -------- Core Logic (Simulation Engine) --------
def generate_demo_data(use_case: str, complexity: str):
    
    components = [
        "API Gateway",
        "Auth Service",
        "Payment Service",
        "Database"
    ]

    logs = [
        f"{use_case}: Service started",
        f"{use_case}: Processing request",
        f"{use_case}: Random failure occurred",
        f"{use_case}: Retrying request"
    ]

    insights = [
        "High latency detected in Payment Service",
        "Retry mechanism triggered",
        "Potential bottleneck in DB connections"
    ]

    # simulate complexity impact
    if complexity == "high":
        logs.append("Cascading failure across services")
        insights.append("System-wide degradation detected")

    return components, logs, insights


# -------- API Endpoint --------
@app.post("/generate-demo", response_model=DemoResponse)
def generate_demo(request: DemoRequest):

    demo_id = str(uuid.uuid4())

    components, logs, insights = generate_demo_data(
        request.use_case,
        request.complexity
    )

    return DemoResponse(
        demo_id=demo_id,
        status="generated",
        components=components,
        logs=logs,
        insights=insights
    )
