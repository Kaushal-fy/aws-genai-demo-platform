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

### Phase 0.3 - Persistence simulation (fully AWS-backed when env is configured)
Status: DONE
Evidence:
- S3 path is REAL AWS S3 (boto3 put_object) in app/storage/s3_store.py
- DynamoDB metadata path is REAL when `GENAI_METADATA_TABLE` is set in app/storage/db_store.py
- In-memory fallback remains only for local/dev execution without AWS env vars

### Phase 0.4 - GenAI layer design
Status: DONE
Evidence:
- Prompt templates: app/llm/prompt_templates.py
- LLM abstraction: app/llm/llm_client.py
- Response validation: app/llm/response_parser.py
- `llm_client.py` can invoke Bedrock Runtime when `GENAI_USE_BEDROCK=true` and a model ID is configured
- Mock fallback still exists for local/dev execution

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

### Phase 2.0 - API Gateway + Lambda entry
Status: CODE READY, DEPLOYMENT DOCUMENTED
Evidence:
- Lambda handlers added in `lambda_handlers.py`
- Shared job submission and lookup logic added in `app/workflow/job_actions.py`
- FastAPI routes now reuse the same shared logic
- AWS CLI and Console deployment steps documented for Lambda/API Gateway

### Phase 2.2 - Replace file queue with SQS
Status: DONE
Evidence:
- `app/workflow/job_queue.py` uses SQS
- worker acknowledges queue messages only after successful completion

### Phase 2.3 - Replace file job store with DynamoDB
Status: DONE
Evidence:
- `app/workflow/job_store.py` uses real DynamoDB
- worker updates job status to `PENDING`, `RUNNING`, `COMPLETED`, and `FAILED`

## Important architecture note
Current architecture is AWS-backed for queue and job state:
- DynamoDB stores async job status
- SQS stores work messages
- S3 stores generated artifacts

## Pending high-priority work
1. Deploy and validate Lambda + API Gateway in AWS.
2. Replace EC2 worker hosting with ECS/Fargate in the live environment.
3. Validate Bedrock model access and runtime responses in the target AWS account.
4. Add curated analytics ingestion into Athena/Redshift beyond raw artifact storage.
