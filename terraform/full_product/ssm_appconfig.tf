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
  count = var.enable_appconfig ? 1 : 0

  name        = "${local.name_prefix}-appconfig"
  description = "AppConfig application for GenAI platform runtime controls"
}

resource "aws_appconfig_environment" "main" {
  count = var.enable_appconfig ? 1 : 0

  application_id = aws_appconfig_application.main[0].id
  name           = var.environment
  description    = "${var.environment} environment"
}

resource "aws_appconfig_configuration_profile" "runtime" {
  count = var.enable_appconfig ? 1 : 0

  application_id = aws_appconfig_application.main[0].id
  location_uri   = "hosted"
  name           = "runtime-config"
  type           = "AWS.Freeform"
}

resource "aws_appconfig_hosted_configuration_version" "runtime" {
  count = var.enable_appconfig ? 1 : 0

  application_id           = aws_appconfig_application.main[0].id
  configuration_profile_id = aws_appconfig_configuration_profile.runtime[0].configuration_profile_id
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
  count = var.enable_appconfig ? 1 : 0

  application_id           = aws_appconfig_application.main[0].id
  configuration_profile_id = aws_appconfig_configuration_profile.runtime[0].configuration_profile_id
  configuration_version    = aws_appconfig_hosted_configuration_version.runtime[0].version_number
  deployment_strategy_id   = "AppConfig.AllAtOnce"
  environment_id           = aws_appconfig_environment.main[0].environment_id
  description              = "Initial runtime configuration deployment"
}