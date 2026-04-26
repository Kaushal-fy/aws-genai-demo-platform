# FULL ROADMAP RESET: full_app_aws (Fresh Sandbox)

This plan assumes a new sandbox where nothing is trusted as completed.
Current starting point:
- New EC2 exists
- No IAM role attached
- No validated AWS resources for this app

The sequence below keeps your original roadmap but makes it executable in order.

## How to use this plan
1. Execute one step at a time.
2. Mark each step DONE only after validation is successful.
3. Do not jump phases until all Required checks pass.

---

## PHASE 0 - Rebuild Foundation Locally (on EC2 host)

### 0.0 FastAPI Skeleton
Goal:
- Start API and verify endpoints are reachable.

Required checks:
- Uvicorn starts with app.main:app.
- /docs is accessible.

Commands:
```bash
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn pydantic boto3
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 0.1 Layered Architecture Validation
Goal:
- Confirm API -> workflow -> worker -> service -> generator path is wired.

Required checks:
- POST /generate-demo-async returns job_id and QUEUED.
- GET /job/{job_id} shows PENDING before worker picks it.

### 0.2 Observability Basics
Goal:
- Confirm structured logs and latency logs appear in terminal.

Required checks:
- log events include request_received, llm_request_start, llm_request_complete, latency.

### 0.3 Persistence Simulation (Workflow State)
Goal:
- Validate queue and jobs are persisted in files.

Required checks:
- jobs.json is updated on submit.
- queue.json appends then drains job IDs when worker runs.

### 0.4 GenAI Layer Design (Mock)
Goal:
- Validate prompt/template/client/parser chain.

Required checks:
- generator returns components, logs, insights with parser validation.

### 0.5 Async Orchestration
Goal:
- Run worker in separate process and complete jobs.

Commands:
```bash
# terminal 1
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000

# terminal 2
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws
source .venv/bin/activate
python run_worker.py
```

Required checks:
- Job status transitions PENDING -> RUNNING -> COMPLETED.

---

## PHASE 1 - AWS Entry (EC2 + S3 + IAM)

### 1.0 Attach IAM Role and Validate S3
Goal:
- Enable real S3 writes from app/storage/s3_store.py.

Required checks:
- EC2 has IAM role with s3:PutObject/ListBucket/GetObject on bucket.
- Completed jobs include storage.s3 details.
- Objects visible in S3 bucket.

### 1.1 Worker as Service
Goal:
- Run worker as persistent background service.

Required checks:
- systemd service enabled and active.
- Worker auto-restarts after reboot/failure.

---

## PHASE 2 - Serverless Entry + Queue Replacement

### 2.0 API Gateway + Lambda Entry
Goal:
- Public API entry moved to API Gateway/Lambda.

### 2.1 Lambda Job Trigger
Goal:
- Lambda submits jobs (decouple internet entry from EC2 app).

### 2.2 Replace File Queue with SQS
Goal:
- queue.json removed from runtime path.
- Worker consumes SQS messages.

### 2.3 Replace File Job Store with DynamoDB
Goal:
- jobs.json removed from runtime path.
- Job status tracked in DynamoDB.

---

## PHASE 3 - Data Layer Hardening

### 3.0 DynamoDB Proper Schema
Goal:
- Finalize partition/sort key and query access patterns.

### 3.1 RDS Integration
Goal:
- Persist relational outputs for reporting queries.

### 3.2 Data Access Layer
Goal:
- Clear repository abstraction for DynamoDB/RDS access.

---

## PHASE 4 - Real GenAI Integration

### 4.0 Bedrock Integration
Goal:
- Replace mock in llm_client with Bedrock Runtime call.

### 4.1 Multi-model Routing
Goal:
- Route use cases across Haiku/Sonnet as required.

### 4.2 Retry + Fallback
Goal:
- Standardized retry and fallback when model/provider fails.

### 4.3 Prompt Pipelines
Goal:
- Dynamic prompt composition and scenario generation.

---

## PHASE 5 - Containerization and Compute Scaling

### 5.0 Dockerize API and Worker
### 5.1 ECS Basics
### 5.2 Fargate
### 5.3 ALB Integration

---

## PHASE 6 - Orchestration Layer

### 6.0 Lambda Orchestration
### 6.1 Workflow Design
### 6.2 Failure Handling and Idempotency

---

## PHASE 7 - Config and Security

### 7.0 Systems Manager Parameter Store
### 7.1 AppConfig
### 7.2 KMS
### 7.3 IAM Hardening

---

## PHASE 8 - Advanced Observability

### 8.0 CloudWatch dashboards/metrics
### 8.1 X-Ray tracing
### 8.2 End-to-end traceability across services

---

## PHASE 9 - Data Engineering Layer

### 9.0 Athena on S3 data
### 9.1 Glue ETL
### 9.2 Redshift analytics

---

## PHASE 10 - Advanced GenAI System

### 10.0 Scenario engine
### 10.1 Multi-step GenAI pipelines
### 10.2 Agent-like behavior

---

## PHASE 11 - Platform Hardening

### 11.0 API security and auth
### 11.1 Resilience patterns
### 11.2 Cost optimization and controls

---

## PHASE 12 - Terraform Finalization

### 12.0 Base IaC (EC2/S3/IAM)
### 12.1 Modular Terraform
### 12.2 Full stack conversion
### 12.3 CI/CD integration

---

## Immediate next action in this sandbox
Start with PHASE 1.0 first because EC2 has no role attached yet.
After role attach and S3 validation, run PHASE 0.5 async validation again end-to-end.