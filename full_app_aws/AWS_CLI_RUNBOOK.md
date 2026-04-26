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
