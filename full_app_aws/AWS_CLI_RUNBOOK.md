# AWS CLI Runbook for full_app_aws

Use this file for command-driven setup and validation on AWS.

## 0) Verify AWS identity

```bash
aws sts get-caller-identity
aws configure list
```

## 1) Region and variables

```bash
export AWS_REGION=us-east-1
export BUCKET_NAME=genai-demo-platform-975049994880
```

## 2) Ensure S3 bucket exists

```bash
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null || \
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
```

Note:
- us-east-1 create-bucket does not require LocationConstraint.

## 3) Validate S3 write permissions

```bash
echo '{"ok":true}' > /tmp/s3-test.json
aws s3 cp /tmp/s3-test.json s3://$BUCKET_NAME/health/s3-write-test.json
aws s3 ls s3://$BUCKET_NAME/health/
```

## 4) Launch API on EC2 host
SSH into EC2 then run:

```bash
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn pydantic boto3
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## 5) Launch worker on EC2 host
In a second SSH session:

```bash
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws
source .venv/bin/activate
python run_worker.py
```

## 6) Submit async request and poll

```bash
API=http://<EC2_PUBLIC_IP>:8000

curl -s -X POST "$API/generate-demo-async" \
  -H "Content-Type: application/json" \
  -d '{"use_case":"checkout failure","complexity":"high"}'
```

Copy job_id from response and poll:

```bash
JOB_ID=<paste_job_id>
curl -s "$API/job/$JOB_ID"
```

## 7) Verify workflow files on EC2

```bash
cd /home/ec2-user/aws-genai-demo-platform/full_app_aws
cat jobs.json
cat queue.json
```

## 8) Verify uploaded demo files in S3

```bash
aws s3 ls s3://$BUCKET_NAME/ | head
aws s3 cp s3://$BUCKET_NAME/<s3_key_from_response> -
```

## 9) Optional: create a systemd service for worker
Create service file:

```bash
sudo tee /etc/systemd/system/genai-worker.service > /dev/null <<'EOF'
[Unit]
Description=GenAI Demo Worker
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/aws-genai-demo-platform/full_app_aws
Environment=PATH=/home/ec2-user/aws-genai-demo-platform/full_app_aws/.venv/bin
ExecStart=/home/ec2-user/aws-genai-demo-platform/full_app_aws/.venv/bin/python run_worker.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable genai-worker
sudo systemctl start genai-worker
sudo systemctl status genai-worker --no-pager
```

## 10) Troubleshooting commands

```bash
# API process
ps -ef | grep uvicorn | grep -v grep

# Worker process
ps -ef | grep run_worker.py | grep -v grep

# Port check
sudo ss -lntp | grep :8000

# Last service logs if using systemd
sudo journalctl -u genai-worker -n 100 --no-pager
```

## 11) Lambda + API Gateway serverless entry

This section moves the public API entrypoint from EC2 FastAPI to API Gateway + Lambda while keeping the EC2 worker unchanged.

### 11.1 Set variables

Run in CloudShell:
```bash
export AWS_REGION=us-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export LAMBDA_ROLE_NAME=GenAIDemoLambdaRole
export LAMBDA_FUNCTION_NAME=genai-demo-api
export API_NAME=genai-demo-http-api
export JOBS_TABLE=genai-demo-jobs
export QUEUE_NAME=genai-demo-jobs
export QUEUE_URL=$(aws sqs get-queue-url --region "$AWS_REGION" --queue-name "$QUEUE_NAME" --query QueueUrl --output text)
export QUEUE_ARN=$(aws sqs get-queue-attributes --region "$AWS_REGION" --queue-url "$QUEUE_URL" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
export JOBS_TABLE_ARN=$(aws dynamodb describe-table --region "$AWS_REGION" --table-name "$JOBS_TABLE" --query 'Table.TableArn' --output text)
```

### 11.2 Create Lambda execution role

Trust policy:
```bash
cat > /tmp/genai-lambda-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name "$LAMBDA_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/genai-lambda-trust.json
```

Attach CloudWatch Logs basic policy:
```bash
aws iam attach-role-policy \
  --role-name "$LAMBDA_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

Attach app permissions:
```bash
cat > /tmp/genai-lambda-app-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem"
      ],
      "Resource": "$JOBS_TABLE_ARN"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:GetQueueUrl",
        "sqs:SendMessage"
      ],
      "Resource": "$QUEUE_ARN"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$LAMBDA_ROLE_NAME" \
  --policy-name GenAIDemoLambdaAppPolicy \
  --policy-document file:///tmp/genai-lambda-app-policy.json
```

Wait briefly for IAM propagation before creating Lambda.

### 11.3 Build Lambda deployment zip

Run from the repository root or CloudShell clone:
```bash
cd ~/aws-genai-demo-platform/full_app_aws
rm -f lambda_bundle.zip
zip -r lambda_bundle.zip lambda_handlers.py app
```

Notes:
- Lambda code path only needs `lambda_handlers.py` and the `app` directory.
- It does not depend on FastAPI at runtime.

### 11.4 Create Lambda function

```bash
export LAMBDA_ROLE_ARN=$(aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text)

aws lambda create-function \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --runtime python3.12 \
  --handler lambda_handlers.api_gateway_router \
  --zip-file fileb://lambda_bundle.zip \
  --role "$LAMBDA_ROLE_ARN" \
  --timeout 30 \
  --environment "Variables={AWS_REGION=$AWS_REGION,GENAI_JOBS_TABLE=$JOBS_TABLE,GENAI_QUEUE_NAME=$QUEUE_NAME}"
```

Update command for later code changes:
```bash
aws lambda update-function-code \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --zip-file fileb://lambda_bundle.zip
```

### 11.5 Create HTTP API Gateway

```bash
export API_ID=$(aws apigatewayv2 create-api \
  --region "$AWS_REGION" \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --query ApiId \
  --output text)

export LAMBDA_ARN=$(aws lambda get-function \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --query 'Configuration.FunctionArn' \
  --output text)

export INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --region "$AWS_REGION" \
  --api-id "$API_ID" \
  --integration-type AWS_PROXY \
  --integration-uri "$LAMBDA_ARN" \
  --payload-format-version 2.0 \
  --query IntegrationId \
  --output text)
```

Create routes:
```bash
aws apigatewayv2 create-route \
  --region "$AWS_REGION" \
  --api-id "$API_ID" \
  --route-key 'POST /generate-demo-async' \
  --target integrations/$INTEGRATION_ID

aws apigatewayv2 create-route \
  --region "$AWS_REGION" \
  --api-id "$API_ID" \
  --route-key 'GET /job/{job_id}' \
  --target integrations/$INTEGRATION_ID
```

Create stage:
```bash
aws apigatewayv2 create-stage \
  --region "$AWS_REGION" \
  --api-id "$API_ID" \
  --stage-name prod \
  --auto-deploy
```

Allow API Gateway to invoke Lambda:
```bash
aws lambda add-permission \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --statement-id apigw-invoke-genai-demo-api \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/*"
```

### 11.6 Validate Lambda directly

Submit:
```bash
aws lambda invoke \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --payload '{"requestContext":{"http":{"method":"POST"}},"rawPath":"/generate-demo-async","body":"{\"use_case\":\"payment\",\"complexity\":\"high\"}"}' \
  /tmp/lambda-submit.json && cat /tmp/lambda-submit.json
```

Get job:
```bash
JOB_ID=<paste_job_id>
aws lambda invoke \
  --region "$AWS_REGION" \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --payload "{\"requestContext\":{\"http\":{\"method\":\"GET\"}},\"rawPath\":\"/job/$JOB_ID\",\"pathParameters\":{\"job_id\":\"$JOB_ID\"}}" \
  /tmp/lambda-get.json && cat /tmp/lambda-get.json
```

### 11.7 Validate through API Gateway

```bash
export API_BASE=https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod

curl -X POST "$API_BASE/generate-demo-async" \
  -H "Content-Type: application/json" \
  -d '{"use_case":"payment","complexity":"high"}'

curl "$API_BASE/job/<JOB_ID>"
```

Expected behavior:
- POST returns `job_id` and `QUEUED`
- DynamoDB shows `PENDING` immediately
- SQS receives a message
- EC2 worker processes it and updates DynamoDB to `COMPLETED` or `FAILED`

### 11.8 Files required for Lambda path

These repository files are part of the Lambda deployment zip or shared logic:
- `lambda_handlers.py`
- `app/workflow/job_actions.py`
- `app/workflow/job_store.py`
- `app/workflow/job_queue.py`

These remain EC2-only runtime files:
- `run_worker.py`
- `app/workflow/worker.py`
- `app/services/demo_service.py`
- `app/storage/s3_store.py`
