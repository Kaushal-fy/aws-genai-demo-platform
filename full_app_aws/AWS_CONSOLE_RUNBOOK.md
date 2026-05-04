# AWS Console Runbook for full_app_aws

Use this file when setup is done from AWS UI (Console) instead of CLI.

## 1) Create or verify S3 bucket
Service: S3

Steps:
1. Open S3 in AWS Console.
2. Click Create bucket.
3. Bucket name: genai-demo-platform-975049994880 (or your unique name).
4. Region: us-east-1.
5. Keep Block Public Access enabled.
6. Create bucket.

Validation:
- Bucket appears in S3 list.

## 2) Create IAM role for EC2
Service: IAM

Steps:
1. Go to IAM > Roles > Create role.
2. Trusted entity: AWS service.
3. Use case: EC2.
4. Attach policy with minimum permissions:
   - s3:PutObject
   - s3:ListBucket
   - s3:GetObject
   on your bucket.
5. Name role: genai-demo-ec2-role.
6. Create role.

Validation:
- Role appears in IAM role list.

## 3) Launch EC2 instance
Service: EC2

Steps:
1. Launch instance (Amazon Linux recommended).
2. Security Group inbound rules:
   - SSH 22 from your IP
   - Custom TCP 8000 from your IP or test CIDR
3. Attach IAM role genai-demo-ec2-role.
4. Launch instance.

Validation:
- Instance status checks pass.

## 4) Deploy code on EC2
Service: EC2 (Connect)

Steps:
1. Connect using EC2 Instance Connect or SSH.
2. Clone repository and move to full_app_aws.
3. Install python dependencies.
4. Run API process and worker process in separate terminals.

Reference commands:
- See AWS_CLI_RUNBOOK.md sections 4 and 5.

## 5) Use FastAPI UI
Open in browser:
- http://<EC2_PUBLIC_IP>:8000/docs

Steps:
1. Expand POST /generate-demo-async.
2. Click Try it out.
3. Provide body:
   {
     "use_case": "payment timeout",
     "complexity": "high"
   }
4. Execute and copy job_id.
5. Expand GET /job/{job_id}.
6. Paste job_id and execute repeatedly until status is COMPLETED.

## 6) Validate S3 object creation from Console
Service: S3

Steps:
1. Open target bucket.
2. Refresh Objects tab.
3. Look for keys named demo-<uuid>.json.
4. Open one object and verify payload includes timestamp and generated data.

## 7) Optional: keep worker always running
Service: EC2 + systemd

Steps:
1. Create systemd service file on EC2.
2. Enable and start the service.
3. Use systemctl status for health.

Reference commands:
- See AWS_CLI_RUNBOOK.md section 9.

## 8) Common UI issues
1. /docs opens but calls fail with timeout
- Check EC2 security group port 8000 inbound.

2. Requests queue but never complete
- Worker process is not running.

3. COMPLETED status but no S3 object
- Verify IAM role permissions and bucket name configured in app/services/demo_service.py.

## 9) API Gateway + Lambda entry (Console)

Goal:
- Replace public FastAPI entry on EC2 with API Gateway + Lambda.
- Keep EC2 worker, SQS, DynamoDB, and S3 as they are.

### 9.1 Create Lambda IAM role
Service: IAM

Steps:
1. Go to IAM > Roles > Create role.
2. Trusted entity: AWS service.
3. Use case: Lambda.
4. Attach `AWSLambdaBasicExecutionRole`.
5. Add inline policy with:
    - `dynamodb:PutItem`
    - `dynamodb:GetItem`
    on `genai-demo-jobs`
    - `sqs:GetQueueUrl`
    - `sqs:SendMessage`
    on `genai-demo-jobs` queue.
6. Name role: `GenAIDemoLambdaRole`.

### 9.2 Create Lambda function
Service: Lambda

Steps:
1. Create function from zip.
2. Function name: `genai-demo-api`.
3. Runtime: Python 3.12.
4. Execution role: `GenAIDemoLambdaRole`.
5. Upload zip containing:
    - `lambda_handlers.py`
    - `app/`
6. Handler: `lambda_handlers.api_gateway_router`.
7. Environment variables:
    - `AWS_REGION=us-east-1`
    - `GENAI_JOBS_TABLE=genai-demo-jobs`
    - `GENAI_QUEUE_NAME=genai-demo-jobs`

### 9.3 Validate Lambda with test event
POST test event:
```json
{
   "requestContext": {
      "http": {
         "method": "POST"
      }
   },
   "rawPath": "/generate-demo-async",
   "body": "{\"use_case\":\"payment\",\"complexity\":\"high\"}"
}
```

GET test event:
```json
{
   "requestContext": {
      "http": {
         "method": "GET"
      }
   },
   "rawPath": "/job/<JOB_ID>",
   "pathParameters": {
      "job_id": "<JOB_ID>"
   }
}
```

### 9.4 Create HTTP API Gateway
Service: API Gateway

Steps:
1. Create API > HTTP API.
2. Add integration: Lambda > `genai-demo-api`.
3. Add routes:
    - `POST /generate-demo-async`
    - `GET /job/{job_id}`
4. Create stage: `prod` with auto deploy enabled.

### 9.5 Validate end-to-end
Steps:
1. Copy API invoke URL.
2. POST to `/generate-demo-async`.
3. Confirm response returns `job_id`.
4. Check DynamoDB item exists.
5. Check SQS queue shows message movement.
6. Confirm EC2 worker processes job and updates status.
7. GET `/job/{job_id}` from API Gateway URL until status is `COMPLETED`.
