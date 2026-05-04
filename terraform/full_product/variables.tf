variable "aws_region" {
  description = "AWS region for the full product deployment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources."
  type        = string
  default     = "genai-demo"
}

variable "environment" {
  description = "Environment name used in resource naming."
  type        = string
  default     = "prod"
}

variable "availability_zones" {
  description = "Availability zones used for the VPC public subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "CIDR block for the application VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for ECS Fargate tasks."
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "jobs_table_name" {
  description = "Optional override for the jobs DynamoDB table name."
  type        = string
  default     = null
}

variable "metadata_table_name" {
  description = "Optional override for the metadata DynamoDB table name."
  type        = string
  default     = null
}

variable "queue_name" {
  description = "Optional override for the main SQS queue name."
  type        = string
  default     = null
}

variable "artifact_bucket_name" {
  description = "Optional override for the S3 artifact bucket name. Must be globally unique if set."
  type        = string
  default     = null
}

variable "worker_image_tag" {
  description = "Docker image tag pushed to ECR for the worker image."
  type        = string
  default     = "latest"
}

variable "build_worker_image" {
  description = "Whether Terraform should build and push the ECS worker image with local Docker."
  type        = bool
  default     = true
}

variable "prebuilt_worker_image_uri" {
  description = "Optional prebuilt worker image URI. Set this if you do not want Terraform to run docker build/push locally."
  type        = string
  default     = null
}

variable "worker_cpu" {
  description = "Fargate CPU units for the worker task."
  type        = number
  default     = 512
}

variable "worker_memory" {
  description = "Fargate memory (MiB) for the worker task."
  type        = number
  default     = 1024
}

variable "worker_desired_count" {
  description = "Number of worker tasks to run."
  type        = number
  default     = 1
}

variable "worker_min_capacity" {
  description = "Minimum autoscaling capacity for the worker service."
  type        = number
  default     = 1
}

variable "worker_max_capacity" {
  description = "Maximum autoscaling capacity for the worker service."
  type        = number
  default     = 3
}

variable "lambda_runtime" {
  description = "Runtime for the API Lambda function."
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Timeout in seconds for the API Lambda function."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Retention period for CloudWatch log groups."
  type        = number
  default     = 30
}

variable "bedrock_model_id" {
  description = "Default Bedrock model ID stored in configuration governance resources."
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "enable_bedrock_runtime" {
  description = "Whether the worker should invoke Bedrock Runtime instead of the mocked LLM response."
  type        = bool
  default     = true
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout for the main job queue."
  type        = number
  default     = 120
}

variable "queue_receive_wait_time_seconds" {
  description = "Long polling duration for the main queue."
  type        = number
  default     = 10
}

variable "enable_glue_athena" {
  description = "Whether to provision Glue catalog and Athena workgroup resources for artifact analytics."
  type        = bool
  default     = true
}

variable "athena_results_bucket_name" {
  description = "Optional override for the Athena results bucket name. Must be globally unique if set."
  type        = string
  default     = null
}

variable "enable_redshift_serverless" {
  description = "Whether to provision Redshift Serverless analytics resources. Disabled by default because of cost."
  type        = bool
  default     = false
}

variable "redshift_admin_username" {
  description = "Admin username for Redshift Serverless when enabled."
  type        = string
  default     = "genaiadmin"
}

variable "redshift_admin_password" {
  description = "Admin password for Redshift Serverless when enabled."
  type        = string
  default     = null
  sensitive   = true
}

variable "redshift_base_capacity" {
  description = "Base RPUs for Redshift Serverless when enabled."
  type        = number
  default     = 32
}

variable "enable_lambda_api" {
  description = "Set to false to skip Lambda + API Gateway creation. Useful in accounts where an SCP blocks lambda:CreateFunction."
  type        = bool
  default     = true
}

variable "enable_appconfig" {
  description = "Set to false to skip AppConfig creation. Useful in accounts where an SCP blocks appconfig:CreateApplication."
  type        = bool
  default     = true
}