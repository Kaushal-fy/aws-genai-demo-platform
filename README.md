# AWS GenAI Demo Platform

This repository contains multiple stages of a GenAI demo platform. The deployable end-product stack lives in `terraform/full_product` and provisions the full AWS architecture around the `full_app_aws` application.

## End-product architecture

The final stack uses:
- API Gateway HTTP API for public entry
- Lambda for request intake and job lookup
- DynamoDB for job state and metadata
- SQS for async job dispatch
- ECS Fargate for worker execution
- S3 for generated artifacts
- Bedrock Runtime for model inference with mock fallback
- SSM Parameter Store and AppConfig for runtime configuration
- CloudWatch and X-Ray for operational visibility
- Glue, Athena, and optional Redshift Serverless for analytics

## Where to start

If your goal is to deploy the whole product, use:
- `terraform/full_product/README.md`

That guide contains:
- exact variable setup
- deploy modes with and without Docker
- exact `terraform apply` flow
- how to test the API
- how to verify ECS, SQS, DynamoDB, and S3
- how to use Glue, Athena, Redshift, CloudWatch, and X-Ray

## Relevant code paths

Application runtime:
- `full_app_aws/app/`
- `full_app_aws/lambda_handlers.py`
- `full_app_aws/run_worker.py`
- `full_app_aws/Dockerfile.worker`

Infrastructure:
- `terraform/full_product/`

## Notes

- The legacy `infra/` and `full_app/` directories show earlier evolution stages.
- The current end-product target is the Terraform stack in `terraform/full_product`.
- Redshift Serverless is optional and disabled by default because of cost.
