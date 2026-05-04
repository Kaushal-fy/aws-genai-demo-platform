resource "aws_dynamodb_table" "jobs" {
  name         = local.jobs_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id"

  attribute {
    name = "job_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.artifacts.arn
  }
}

resource "aws_dynamodb_table" "metadata" {
  name         = local.metadata_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "demo_id"

  attribute {
    name = "demo_id"
    type = "S"
  }

  attribute {
    name = "use_case"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "use-case-created-at"
    hash_key        = "use_case"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.artifacts.arn
  }
}