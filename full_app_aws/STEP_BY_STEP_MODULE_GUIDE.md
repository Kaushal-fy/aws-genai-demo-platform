# full_app_aws Step-by-Step Module Guide

This guide explains each module in execution order and how to run and validate it.

## 1) Environment setup
Run from repository root:

```bash
cd /home/kthakur/Downloads/GenAi/aws-genai-demo-platform/full_app_aws
python -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn pydantic boto3
```

## 2) Start API process

```bash
cd /home/kthakur/Downloads/GenAi/aws-genai-demo-platform/full_app_aws
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

What this activates:
- app/main.py
- app/api/routes.py

Validation:
- Open http://<host>:8000/docs
- Confirm endpoints exist:
  - POST /generate-demo-async
  - GET /job/{job_id}

## 3) Submit async job

```bash
curl -X POST http://<host>:8000/generate-demo-async \
  -H "Content-Type: application/json" \
  -d '{"use_case":"payment failed","complexity":"high"}'
```

Expected output:
- job_id
- status QUEUED

What happened internally:
1. app/api/routes.py validates input with DemoRequest.
2. app/workflow/job_store.py creates a PENDING job in jobs.json.
3. app/workflow/job_queue.py appends job_id to queue.json.

## 4) Start worker process
Open a second terminal:

```bash
cd /home/kthakur/Downloads/GenAi/aws-genai-demo-platform/full_app_aws
source .venv/bin/activate
python run_worker.py
```

What this activates:
- run_worker.py
- app/workflow/worker.py

Worker loop behavior:
1. Pops job id from queue.json.
2. Loads job from jobs.json.
3. Marks status RUNNING.
4. Calls app/services/demo_service.py.
5. Marks status COMPLETED with result.

## 5) Poll job status

```bash
curl http://<host>:8000/job/<job_id>
```

Expected transitions:
- PENDING -> RUNNING -> COMPLETED

## 6) Understand service and generation path
When worker executes service.create_demo:

1. app/core/observability.py
- start_trace() creates trace id
- log() prints structured events
- time_it() logs latency

2. app/core/generator.py
- logs llm_request_start
- calls LLM abstraction
- validates response
- logs llm_request_complete

3. app/llm modules
- prompt_templates.py builds prompt text
- llm_client.py returns mocked LLM response
- response_parser.py validates keys

4. app/storage modules
- s3_store.py uploads full payload to S3 bucket using boto3
- db_store.py stores metadata in memory (simulated DynamoDB)

## 7) Verify output artifacts
Check file-backed workflow state:

```bash
cat jobs.json
cat queue.json
```

Check S3 upload (replace bucket if needed):

```bash
aws s3 ls s3://genai-demo-platform-975049994880/
```

## 8) Common issues and fixes
1. Error: missing credentials
- Configure IAM role on EC2 or run aws configure locally.

2. Jobs stay QUEUED forever
- Worker process not running.

3. /job returns null
- Wrong job_id or API started in different working directory.

4. No S3 object created
- Check bucket name in app/services/demo_service.py and IAM permission s3:PutObject.

## 9) Next module completion order
1. Replace app/storage/db_store.py with real DynamoDB access.
2. Add FAILED state handling in worker exception path.
3. Replace mocked app/llm/llm_client.py with Bedrock Runtime call.
4. Add systemd service for worker (Phase 1.1).
