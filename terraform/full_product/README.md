# Full Product Terraform Stack

This stack provisions the end-product AWS architecture for the GenAI demo platform.

Core runtime resources:
- API Gateway HTTP API
- Lambda API entrypoint
- DynamoDB jobs table
- DynamoDB metadata table
- SQS main queue and dead-letter queue
- S3 artifact bucket with SSE-KMS
- ECS Fargate worker service
- ECR repository for the worker container image
- CloudWatch log groups, dashboard, and alarms
- X-Ray for Lambda plus ECS worker sidecar daemon
- SSM Parameter Store values
- AppConfig application, environment, profile, and deployment

Analytics resources:
- Glue catalog database
- Glue crawler over the S3 `artifacts/` prefix
- Athena workgroup and results bucket
- Optional Redshift Serverless namespace and workgroup

## Deployment modes

Two supported deployment modes exist.

### Mode A: One-pass deploy from a machine with Docker
Use this if the machine running Terraform has:
- Docker daemon
- AWS CLI
- Terraform

Terraform will:
- create ECR
- build `full_app_aws/Dockerfile.worker`
- push the worker image
- create ECS service using that image

### Mode B: One-pass deploy with a prebuilt image
Use this if Docker is not available on the machine running Terraform.

You manually build and push the worker image first, then provide `prebuilt_worker_image_uri` and set `build_worker_image = false`.

## Preconditions

You need:
- AWS credentials with permissions to create VPC, ECS, Lambda, API Gateway, DynamoDB, SQS, S3, IAM, KMS, CloudWatch, X-Ray, SSM, AppConfig, Glue, Athena, and optionally Redshift Serverless
- Terraform 1.6+
- AWS provider access to the target account

For Mode A only:
- Docker daemon available locally
- AWS CLI available locally

## Files this stack depends on

Application code consumed by this stack:
- `full_app_aws/lambda_handlers.py`
- `full_app_aws/app/workflow/job_actions.py`
- `full_app_aws/app/workflow/job_store.py`
- `full_app_aws/app/workflow/job_queue.py`
- `full_app_aws/app/workflow/worker.py`
- `full_app_aws/app/services/demo_service.py`
- `full_app_aws/app/storage/s3_store.py`
- `full_app_aws/app/storage/db_store.py`
- `full_app_aws/app/llm/llm_client.py`
- `full_app_aws/Dockerfile.worker`

## Step 1: Prepare variables

```bash
cd terraform/full_product
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`.

Minimum required values for a working deployment:

```hcl
aws_region       = "us-east-1"
project_name     = "genai-demo"
environment      = "prod"
worker_image_tag = "v1"

# Optional: keep null to auto-generate a globally unique bucket name.
artifact_bucket_name = null

# Bedrock runtime is enabled by default for the worker.
bedrock_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
```

### If you are using Mode A (Docker available)
Keep these defaults or set explicitly:

```hcl
build_worker_image       = true
prebuilt_worker_image_uri = null
```

### If you are using Mode B (prebuilt image)
Set:

```hcl
build_worker_image        = false
prebuilt_worker_image_uri = "<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>"
```

### If you want Redshift Serverless too
Redshift is disabled by default because of cost.

Set:

```hcl
enable_redshift_serverless = true
redshift_admin_username    = "genaiadmin"
redshift_admin_password    = "<strong-password>"
```

## Step 2: Optional prebuild path for the worker image

Only do this if you are using Mode B.

1. Create infrastructure after temporarily setting `build_worker_image = false` and `prebuilt_worker_image_uri = "public.ecr.aws/docker/library/busybox:latest"` if you want ECR created first, or create your target ECR repo manually.
2. Build and push the real worker image.
3. Update `prebuilt_worker_image_uri` to the real image.
4. Re-run `terraform apply`.

Recommended simpler approach: use Mode A if possible.

## Step 3: Deploy

```bash
terraform init
terraform apply
```

Expected result:
- VPC and subnets created
- KMS key created
- S3 bucket created
- DynamoDB tables created
- SQS queues created
- Lambda created
- HTTP API created
- ECR repo created
- ECS worker created
- SSM/AppConfig created
- CloudWatch/X-Ray resources created
- Glue and Athena created
- Redshift created only if enabled

## Step 4: Capture outputs

After apply completes, collect these outputs:

```bash
terraform output api_base_url
terraform output artifact_bucket_name
terraform output jobs_table_name
terraform output metadata_table_name
terraform output queue_url
terraform output athena_workgroup_name
terraform output glue_database_name
terraform output glue_crawler_name
terraform output athena_results_bucket_name
terraform output redshift_workgroup_name
terraform output redshift_namespace_name
```

## Step 5: Test the application

### Submit a job

```bash
API_BASE_URL=$(terraform output -raw api_base_url)

curl -X POST "$API_BASE_URL/generate-demo-async" \
  -H "Content-Type: application/json" \
  -d '{"use_case":"payment","complexity":"high"}'
```

Expected response:

```json
{
  "job_id": "<uuid>",
  "status": "QUEUED"
}
```

### Poll a job

```bash
JOB_ID=<paste-job-id>
curl "$API_BASE_URL/job/$JOB_ID"
```

Expected lifecycle:
- `PENDING`
- `RUNNING`
- `COMPLETED` or `FAILED`

### Verify artifact upload

1. Get the `s3_key` from the completed job result.
2. Read the object:

```bash
BUCKET=$(terraform output -raw artifact_bucket_name)
aws s3 cp "s3://$BUCKET/<s3_key>" -
```

Expected object location prefix:
- `artifacts/demo-<uuid>.json`

## How the deployed application works

1. User calls API Gateway.
2. API Gateway invokes Lambda.
3. Lambda writes a `PENDING` job item to DynamoDB.
4. Lambda sends the `job_id` to SQS.
5. ECS Fargate worker polls SQS.
6. Worker updates DynamoDB to `RUNNING`.
7. Worker calls Bedrock if `enable_bedrock_runtime = true`; otherwise it falls back to the mock response.
8. Worker stores the full artifact in S3.
9. Worker stores metadata in the metadata DynamoDB table.
10. Worker updates the job item to `COMPLETED` or `FAILED`.
11. Worker acknowledges the SQS message only after success.

## How to use the application

Main API endpoints:
- `POST /generate-demo-async`
- `GET /job/{job_id}`

Example request body:

```json
{
  "use_case": "ecommerce",
  "complexity": "high"
}
```

Example completed result contains:
- `components`
- `logs`
- `insights`
- `storage.s3.bucket`
- `storage.s3.s3_key`
- metadata counts in the metadata table

## How to use CloudWatch

### Logs
Use CloudWatch Logs to inspect:
- Lambda logs: `/aws/lambda/<function-name>`
- ECS worker logs: `/ecs/<service-name>`
- API Gateway access logs: `/aws/apigateway/<name>`

### Dashboard
A dashboard is created automatically.
It shows:
- SQS queue depth
- Lambda invocations and errors
- ECS CPU utilization
- DynamoDB throttle events

### Alarms
The stack creates alarms for:
- queue backlog
- Lambda errors

Use these to detect worker lag or API failures.

## How to use X-Ray

X-Ray is enabled for:
- Lambda via active tracing
- ECS worker through the X-Ray daemon sidecar

Use the X-Ray console to trace:
- API request into Lambda
- downstream AWS SDK calls where supported
- worker behavior during processing

What X-Ray helps answer:
- where time was spent
- whether Lambda was fast but worker was slow
- whether downstream AWS calls are failing

## How to use Glue

Glue is provisioned for artifact cataloging.

Resources created:
- Glue database
- Glue crawler pointing to `s3://<artifact-bucket>/artifacts/`

### Run the crawler

```bash
CRAWLER=$(terraform output -raw glue_crawler_name)
aws glue start-crawler --name "$CRAWLER"
```

Wait for it to finish, then inspect the generated tables in the Glue database.

## How to use Athena

Athena is provisioned with:
- a workgroup
- a results bucket
- Glue catalog integration through the crawler

### Query artifacts

1. Run the Glue crawler first.
2. Open Athena console.
3. Select the deployed workgroup.
4. Choose the deployed Glue database.
5. Select the table created by the crawler.
6. Run SQL queries.

Example query after crawler creates a table:

```sql
SELECT *
FROM <glue_generated_table>
LIMIT 10;
```

Typical use cases:
- inspect generated artifacts
- analyze generated components and insights across jobs
- build ad hoc operational analytics

## How to use Redshift Serverless

Redshift is optional and only exists if `enable_redshift_serverless = true`.

Use it when you want warehouse-style analytics beyond Athena.

### Typical workflow

1. Generate artifacts into S3.
2. Use Glue/Athena to catalog the data.
3. Use Redshift Query Editor v2 to connect to the serverless workgroup.
4. Create external schema or copy curated data into Redshift tables.
5. Run aggregated analytics.

Example scenarios:
- count jobs by `use_case`
- compare component patterns by complexity
- analyze insights frequency over time

## Manual verification checklist

After deployment, verify all of the following:

1. API Gateway responds to POST and GET.
2. Lambda logs appear in CloudWatch.
3. DynamoDB jobs table receives job items.
4. SQS queue receives messages.
5. ECS service has running tasks.
6. ECS worker logs show `worker_start` and `worker_complete`.
7. S3 bucket contains objects under `artifacts/`.
8. Metadata DynamoDB table receives records.
9. CloudWatch dashboard renders metrics.
10. X-Ray traces appear for Lambda and worker paths.
11. Glue crawler completes successfully.
12. Athena can query crawled artifact data.
13. Redshift Serverless is reachable only if enabled.

## Known operational notes

- If Docker is unavailable on the Terraform machine, use Mode B with a prebuilt image.
- Bedrock invocation requires account access to the chosen model ID.
- Redshift Serverless is disabled by default because it adds cost.
- Glue crawler needs sample files under `artifacts/` before cataloging produces tables.
- The stack provisions the metadata DynamoDB table and the app now writes to it when `GENAI_METADATA_TABLE` is present.
