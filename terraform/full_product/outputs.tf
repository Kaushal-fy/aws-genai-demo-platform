output "api_base_url" {
  description = "HTTP API base URL for the serverless entrypoint. Null when enable_lambda_api = false."
  value       = try(aws_apigatewayv2_stage.prod[0].invoke_url, null)
}

output "lambda_function_name" {
  description = "Lambda function serving API Gateway requests. Null when enable_lambda_api = false."
  value       = try(aws_lambda_function.api[0].function_name, null)
}

output "worker_cluster_name" {
  description = "ECS cluster name for the worker service."
  value       = aws_ecs_cluster.main.name
}

output "worker_service_name" {
  description = "ECS service name for the worker service."
  value       = aws_ecs_service.worker.name
}

output "worker_ecr_repository_url" {
  description = "ECR repository used for the worker container image."
  value       = aws_ecr_repository.worker.repository_url
}

output "jobs_table_name" {
  description = "DynamoDB table that stores async job status."
  value       = aws_dynamodb_table.jobs.name
}

output "metadata_table_name" {
  description = "DynamoDB table intended for searchable metadata."
  value       = aws_dynamodb_table.metadata.name
}

output "queue_url" {
  description = "Main SQS queue URL for async job dispatch."
  value       = aws_sqs_queue.jobs.url
}

output "artifact_bucket_name" {
  description = "S3 bucket for generated artifacts."
  value       = aws_s3_bucket.artifacts.bucket
}

output "appconfig_application_id" {
  description = "AppConfig application ID for runtime configuration governance. Null when enable_appconfig = false."
  value       = try(aws_appconfig_application.main[0].id, null)
}

output "ssm_parameter_prefix" {
  description = "Parameter Store prefix containing deployed configuration values."
  value       = "/${var.project_name}/${var.environment}"
}

output "athena_workgroup_name" {
  description = "Athena workgroup for querying generated artifacts."
  value       = try(aws_athena_workgroup.analytics[0].name, null)
}

output "glue_database_name" {
  description = "Glue catalog database for artifact discovery."
  value       = try(aws_glue_catalog_database.analytics[0].name, null)
}

output "glue_crawler_name" {
  description = "Glue crawler used to catalog artifacts from S3."
  value       = try(aws_glue_crawler.artifacts[0].name, null)
}

output "athena_results_bucket_name" {
  description = "S3 bucket used by Athena for query results."
  value       = try(aws_s3_bucket.athena_results[0].bucket, null)
}

output "redshift_workgroup_name" {
  description = "Redshift Serverless workgroup for analytics queries."
  value       = try(aws_redshiftserverless_workgroup.analytics[0].workgroup_name, null)
}

output "redshift_namespace_name" {
  description = "Redshift Serverless namespace for analytics data." 
  value       = try(aws_redshiftserverless_namespace.analytics[0].namespace_name, null)
}