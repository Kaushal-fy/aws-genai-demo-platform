# full_app_aws Implementation Progress

## Scope
This file tracks what is implemented in full_app_aws and what is pending, mapped to the roadmap in plan.md.

## Completed in this directory

### Phase 0.0 - FastAPI skeleton
Status: DONE
Evidence:
- app/main.py creates FastAPI app and includes router.

### Phase 0.1 - Layered architecture
Status: DONE
Evidence:
- API layer: app/api/routes.py
- Service layer: app/services/demo_service.py
- Core generation layer: app/core/generator.py

### Phase 0.2 - Observability basics
Status: DONE
Evidence:
- app/core/observability.py has trace id, structured log, and latency decorator.

### Phase 0.3 - Persistence simulation (partially upgraded)
Status: PARTIAL
Evidence:
- S3 path is REAL AWS S3 (boto3 put_object) in app/storage/s3_store.py
- DynamoDB path is still simulated in memory in app/storage/db_store.py

### Phase 0.4 - GenAI layer design
Status: DONE (mocked)
Evidence:
- Prompt templates: app/llm/prompt_templates.py
- LLM abstraction: app/llm/llm_client.py
- Response validation: app/llm/response_parser.py
- Note: llm_client is still mocked, not real Bedrock call.

### Phase 0.5 - Async orchestration
Status: DONE
Evidence:
- Async API endpoint and status endpoint in app/api/routes.py
- Queue and job store in app/workflow
- Worker loop in app/workflow/worker.py
- Worker bootstrap in run_worker.py

### Phase 1.0 - AWS entry
Status: PARTIAL
Evidence:
- App is intended for EC2 deployment and already uses real S3.
- IAM role and instance setup are operational tasks (documented in AWS_CONSOLE_RUNBOOK.md and AWS_CLI_RUNBOOK.md).

## Important architecture note
Queue and job state are file-backed:
- jobs.json
- queue.json
This allows API and worker processes on the same host to share state.

## Pending high-priority work
1. Replace simulated DynamoDB in app/storage/db_store.py with real DynamoDB table writes.
2. Replace mocked llm_client with Bedrock Runtime call.
3. Add worker service management (systemd) for auto-start and restart.
4. Add failure status handling in worker for exceptions (FAILED state).
