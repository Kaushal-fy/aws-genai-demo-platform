data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  jobs_table_name     = coalesce(var.jobs_table_name, "${local.name_prefix}-jobs")
  metadata_table_name = coalesce(var.metadata_table_name, "${local.name_prefix}-metadata")
  queue_name          = coalesce(var.queue_name, "${local.name_prefix}-queue")
  dlq_name            = "${local.queue_name}-dlq"
  artifact_bucket_name = coalesce(
    var.artifact_bucket_name,
    lower("${local.name_prefix}-${data.aws_caller_identity.current.account_id}-artifacts")
  )
  athena_results_bucket_name = coalesce(
    var.athena_results_bucket_name,
    lower("${local.name_prefix}-${data.aws_caller_identity.current.account_id}-athena-results")
  )
  worker_ecr_name      = "${local.name_prefix}-worker"
  api_lambda_name      = "${local.name_prefix}-api"
  worker_cluster_name  = "${local.name_prefix}-cluster"
  worker_service_name  = "${local.name_prefix}-worker"
  dashboard_name       = "${local.name_prefix}-dashboard"
  glue_database_name   = replace("${var.project_name}_${var.environment}_analytics", "-", "_")
  athena_workgroup_name = "${local.name_prefix}-athena"
  redshift_namespace_name = "${local.name_prefix}-analytics"
  redshift_workgroup_name = "${local.name_prefix}-analytics"
  app_source_dir       = abspath("${path.module}/../../full_app_aws")
  worker_image_uri     = coalesce(var.prebuilt_worker_image_uri, "${aws_ecr_repository.worker.repository_url}:${var.worker_image_tag}")
  worker_source_files = distinct(concat(
    fileset(local.app_source_dir, "app/**/*.py"),
    fileset(local.app_source_dir, "*.py"),
    ["Dockerfile.worker"]
  ))
}