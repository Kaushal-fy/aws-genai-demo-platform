# FULL ROADMAP RESET: full_app_aws (Fresh Sandbox)

This plan assumes a new sandbox where nothing is trusted as completed.
Current starting point:
- New EC2 exists
- No IAM role attached
- No validated AWS resources for this app

The sequence below keeps your original roadmap but makes it executable in order.

## Validated Rebuild Runbook (CloudShell -> EC2 -> Working Phase 2.2)

This section captures the exact path that was validated in the sandbox.
Target end state:
- FastAPI running on EC2
- Worker running as systemd service on EC2
- Job state in DynamoDB
- Queue in SQS
- Full generated artifact uploaded to S3
- Worker status transitions: PENDING -> RUNNING -> COMPLETED or FAILED

### AWS resources to create first

Use these names unless you intentionally change them:

- EC2 IAM role: `GenAIDemoEC2Role`
- DynamoDB table: `genai-demo-jobs`
- SQS queue: `genai-demo-jobs`
- S3 bucket: `genai-demo-artifacts-kaush`
- AWS Region: `us-east-1`

### EC2 role permissions required

Attach policies that allow these actions.

S3 policy:
```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"s3:PutObject",
				"s3:GetObject"
			],
			"Resource": "arn:aws:s3:::genai-demo-artifacts-kaush/*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"s3:ListBucket"
			],
			"Resource": "arn:aws:s3:::genai-demo-artifacts-kaush"
		}
	]
}
```

DynamoDB policy:
```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"dynamodb:PutItem",
				"dynamodb:GetItem",
				"dynamodb:UpdateItem"
			],
			"Resource": "arn:aws:dynamodb:us-east-1:*:table/genai-demo-jobs"
		}
	]
}
```

SQS policy:
```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"sqs:GetQueueUrl",
				"sqs:SendMessage",
				"sqs:ReceiveMessage",
				"sqs:DeleteMessage",
				"sqs:GetQueueAttributes"
			],
			"Resource": "arn:aws:sqs:us-east-1:*:genai-demo-jobs"
		}
	]
}
```

Notes:
- Do not use SSE-KMS on the bucket for this phase unless you also add KMS key permissions.
- The bucket used in validation was SSE-S3 (`AES256`).

### AWS resource creation commands

Run from CloudShell or any admin shell:
```bash
aws dynamodb create-table \
	--region us-east-1 \
	--table-name genai-demo-jobs \
	--attribute-definitions AttributeName=job_id,AttributeType=S \
	--key-schema AttributeName=job_id,KeyType=HASH \
	--billing-mode PAY_PER_REQUEST

aws sqs create-queue \
	--region us-east-1 \
	--queue-name genai-demo-jobs

aws s3 mb s3://genai-demo-artifacts-kaush --region us-east-1

aws s3api get-bucket-encryption \
	--bucket genai-demo-artifacts-kaush \
	--region us-east-1
```

Expected S3 encryption result:
- `SSEAlgorithm = AES256`
- No KMS dependency

### EC2 bootstrap commands

Run on EC2:
```bash
cd /home/ec2-user
git clone <repo-url> aws-genai-demo-platform
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws

python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn pydantic boto3
```

### Required environment variables

Run on EC2:
```bash
cat <<'EOF' >> ~/.bashrc
export AWS_REGION=us-east-1
export GENAI_JOBS_TABLE=genai-demo-jobs
export GENAI_QUEUE_NAME=genai-demo-jobs
export GENAI_S3_BUCKET=genai-demo-artifacts-kaush
EOF

source ~/.bashrc
```

### Required EC2 file state

These files must match the validated behavior.

1. `app/workflow/job_store.py`
- DynamoDB-backed job store
- reads `GENAI_JOBS_TABLE`
- reads `AWS_REGION` or `AWS_DEFAULT_REGION`

2. `app/workflow/job_queue.py`
- SQS-backed queue
- reads `GENAI_QUEUE_NAME`
- `pop()` must return `job_id` plus `receipt_handle`
- `ack()` must delete the SQS message only after successful processing

3. `app/workflow/worker.py`
- status transitions:
	- set `RUNNING` before processing
	- set `COMPLETED` on success
	- set `FAILED` with error payload on exception
- acknowledge SQS message only after success

4. `app/services/demo_service.py`
- reads `GENAI_S3_BUCKET` from environment

5. `app/storage/s3_store.py`
- creates S3 client using explicit region from env

### systemd worker service

Create `/etc/systemd/system/genai-worker.service`:
```ini
[Unit]
Description=GenAI Worker Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/aws-genai-demo-platform/full_app_aws
Environment="PATH=/home/ec2-user/aws-genai-demo-platform/full_app_aws/.venv/bin"
Environment="AWS_REGION=us-east-1"
Environment="GENAI_JOBS_TABLE=genai-demo-jobs"
Environment="GENAI_QUEUE_NAME=genai-demo-jobs"
Environment="GENAI_S3_BUCKET=genai-demo-artifacts-kaush"
ExecStart=/home/ec2-user/aws-genai-demo-platform/full_app_aws/.venv/bin/python /home/ec2-user/aws-genai-demo-platform/full_app_aws/run_worker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then enable it:
```bash
sudo systemctl daemon-reload
sudo systemctl enable genai-worker
sudo systemctl restart genai-worker
sudo systemctl status genai-worker --no-pager
```

### API start command

Run on EC2:
```bash
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Validation commands

Submit a job:
```bash
curl -X POST http://<EC2-IP>:8000/generate-demo-async \
	-H "Content-Type: application/json" \
	-d '{"use_case": "payment", "complexity": "high"}'
```

Check a job:
```bash
curl http://<EC2-IP>:8000/job/<JOB_ID>
```

Check worker logs:
```bash
sudo journalctl -u genai-worker -n 100 --no-pager
```

Check queue state:
```bash
aws sqs get-queue-attributes \
	--region us-east-1 \
	--queue-url https://sqs.us-east-1.amazonaws.com/<ACCOUNT_ID>/genai-demo-jobs \
	--attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
```

Check DynamoDB item:
```bash
aws dynamodb get-item \
	--region us-east-1 \
	--table-name genai-demo-jobs \
	--key '{"job_id":{"S":"<JOB_ID>"}}'
```

Check live worker env if status looks wrong:
```bash
pid=$(systemctl show -p MainPID --value genai-worker) && sudo strings /proc/$pid/environ | egrep 'AWS_REGION|GENAI_JOBS_TABLE|GENAI_QUEUE_NAME|GENAI_S3_BUCKET'
```

### Expected job lifecycle

Normal path:
- API writes `PENDING` job to DynamoDB
- API sends `job_id` to SQS
- Worker receives message from SQS
- Worker updates DynamoDB to `RUNNING`
- Worker generates response
- Worker uploads artifact to S3
- Worker updates DynamoDB to `COMPLETED`
- Worker deletes SQS message

Failure path:
- Worker updates DynamoDB to `FAILED`
- Worker stores `{"error": "..."}` in `result`
- Worker does not ack message until the processing path succeeds

### Known pitfalls already hit in this sandbox

1. Missing `AWS_REGION`
- Symptom: `NoRegionError`

2. Bucket encrypted with KMS
- Symptom: `kms:GenerateDataKey` AccessDenied during S3 upload
- Fix: use SSE-S3 bucket for this phase or add KMS permissions

3. Wrong bucket env in systemd
- Symptom: `NoSuchBucket`
- Fix: verify both service file and live worker env

4. Early SQS delete
- Symptom: jobs could remain `PENDING` with lost message
- Fix: only ack after success

5. Worker failure not updating DynamoDB
- Symptom: jobs stuck in `RUNNING`
- Fix: worker now writes `FAILED` on exception

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

Required checks:
- Lambda POST path creates DynamoDB job and pushes to SQS.
- Lambda GET path returns current DynamoDB job state.
- API Gateway routes `POST /generate-demo-async` and `GET /job/{job_id}` invoke Lambda successfully.
- EC2 FastAPI is no longer required for public submission.

Implementation notes:
- Use `lambda_handlers.api_gateway_router` as the Lambda handler.
- Lambda reuses `app/workflow/job_actions.py` shared logic.
- Exact deployment steps are documented in `AWS_CLI_RUNBOOK.md` section 11 and `AWS_CONSOLE_RUNBOOK.md` section 9.

### 2.1 Lambda Job Trigger
Goal:
- Lambda submits jobs (decouple internet entry from EC2 app).

Required checks:
- POST request through Lambda returns `job_id` and `QUEUED`.
- DynamoDB item appears immediately with `PENDING`.
- SQS queue receives the `job_id` message.

### 2.2 Replace File Queue with SQS
Goal:
- queue.json removed from runtime path.
- Worker consumes SQS messages.

Required checks:
- `app/workflow/job_queue.py` uses SQS only.
- Message is acknowledged only after successful job completion.
- Failed jobs are not silently lost by early delete.

### 2.3 Replace File Job Store with DynamoDB
Goal:
- jobs.json removed from runtime path.
- Job status tracked in DynamoDB.

Required checks:
- `create_job()` writes `PENDING` to DynamoDB.
- Worker updates `RUNNING`, `COMPLETED`, or `FAILED` on the same item.
- `GET /job/{job_id}` and Lambda GET both read from DynamoDB.

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