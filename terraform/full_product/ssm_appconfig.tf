resource "aws_ssm_parameter" "jobs_table" {
  name  = "/${var.project_name}/${var.environment}/jobs_table"
  type  = "String"
  value = aws_dynamodb_table.jobs.name
}

resource "aws_ssm_parameter" "metadata_table" {
  name  = "/${var.project_name}/${var.environment}/metadata_table"
  type  = "String"
  value = aws_dynamodb_table.metadata.name
}

resource "aws_ssm_parameter" "queue_name" {
  name  = "/${var.project_name}/${var.environment}/queue_name"
  type  = "String"
  value = aws_sqs_queue.jobs.name
}

resource "aws_ssm_parameter" "bucket_name" {
  name  = "/${var.project_name}/${var.environment}/artifact_bucket"
  type  = "String"
  value = aws_s3_bucket.artifacts.bucket
}

resource "aws_ssm_parameter" "bedrock_model_id" {
  name  = "/${var.project_name}/${var.environment}/bedrock_model_id"
  type  = "String"
  value = var.bedrock_model_id
}

resource "aws_appconfig_application" "main" {
  name        = "${local.name_prefix}-appconfig"
  description = "AppConfig application for GenAI platform runtime controls"
}

resource "aws_appconfig_environment" "main" {
  application_id = aws_appconfig_application.main.id
  name           = var.environment
  description    = "${var.environment} environment"
}

resource "aws_appconfig_configuration_profile" "runtime" {
  application_id = aws_appconfig_application.main.id
  location_uri   = "hosted"
  name           = "runtime-config"
  type           = "AWS.Freeform"
}

resource "aws_appconfig_hosted_configuration_version" "runtime" {
  application_id           = aws_appconfig_application.main.id
  configuration_profile_id = aws_appconfig_configuration_profile.runtime.configuration_profile_id
  content_type             = "application/json"

  content = jsonencode({
    bedrock_model_id = var.bedrock_model_id
    feature_flags = {
      lambda_entry_enabled = true
      xray_enabled         = true
      metadata_indexing    = true
    }
    prompt_versions = {
      demo_generation = "v1"
    }
  })
}

resource "aws_appconfig_deployment" "runtime" {
  application_id           = aws_appconfig_application.main.id
  configuration_profile_id = aws_appconfig_configuration_profile.runtime.configuration_profile_id
  configuration_version    = aws_appconfig_hosted_configuration_version.runtime.version_number
  deployment_strategy_id   = "AppConfig.AllAtOnce"
  environment_id           = aws_appconfig_environment.main.environment_id
  description              = "Initial runtime configuration deployment"
}