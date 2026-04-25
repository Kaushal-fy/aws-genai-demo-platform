from fastapi import FastAPI
from app.api.routes import router

app = FastAPI(title="GenAI Demo Platform - Phase 0.1")

app.include_router(router)
