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
