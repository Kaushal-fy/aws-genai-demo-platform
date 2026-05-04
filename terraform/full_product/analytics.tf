resource "aws_s3_bucket" "athena_results" {
  count         = var.enable_glue_athena ? 1 : 0
  bucket        = local.athena_results_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  count  = var.enable_glue_athena ? 1 : 0
  bucket = aws_s3_bucket.athena_results[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  count  = var.enable_glue_athena ? 1 : 0
  bucket = aws_s3_bucket.athena_results[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.artifacts.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_glue_catalog_database" "analytics" {
  count = var.enable_glue_athena ? 1 : 0
  name  = local.glue_database_name
}

data "aws_iam_policy_document" "glue_assume_role" {
  count = var.enable_glue_athena ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  count              = var.enable_glue_athena ? 1 : 0
  name               = "${local.name_prefix}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  count      = var.enable_glue_athena ? 1 : 0
  role       = aws_iam_role.glue[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_artifacts" {
  count = var.enable_glue_athena ? 1 : 0
  name  = "${local.name_prefix}-glue-artifacts"
  role  = aws_iam_role.glue[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
          aws_s3_bucket.athena_results[0].arn,
          "${aws_s3_bucket.athena_results[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.artifacts.arn
      }
    ]
  })
}

resource "aws_glue_crawler" "artifacts" {
  count         = var.enable_glue_athena ? 1 : 0
  name          = "${local.name_prefix}-artifacts-crawler"
  database_name = aws_glue_catalog_database.analytics[0].name
  role          = aws_iam_role.glue[0].arn
  table_prefix  = "artifacts_"

  s3_target {
    path = "s3://${aws_s3_bucket.artifacts.bucket}/artifacts/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}

resource "aws_athena_workgroup" "analytics" {
  count = var.enable_glue_athena ? 1 : 0
  name  = local.athena_workgroup_name

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results[0].bucket}/results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.artifacts.arn
      }
    }
  }
}

resource "aws_security_group" "redshift" {
  count       = var.enable_redshift_serverless ? 1 : 0
  name        = "${local.name_prefix}-redshift-sg"
  description = "Access policy for Redshift Serverless analytics workgroup"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "redshift" {
  count = var.enable_redshift_serverless ? 1 : 0
  name  = "${local.name_prefix}-redshift-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "redshift_s3" {
  count = var.enable_redshift_serverless ? 1 : 0
  name  = "${local.name_prefix}-redshift-s3"
  role  = aws_iam_role.redshift[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.artifacts.arn
      }
    ]
  })
}

resource "aws_redshiftserverless_namespace" "analytics" {
  count               = var.enable_redshift_serverless ? 1 : 0
  namespace_name      = local.redshift_namespace_name
  db_name             = "genai"
  admin_username      = var.redshift_admin_username
  admin_user_password = var.redshift_admin_password
  iam_roles           = [aws_iam_role.redshift[0].arn]
  kms_key_id          = aws_kms_key.artifacts.arn
  log_exports         = ["userlog", "connectionlog", "useractivitylog"]
}

resource "aws_redshiftserverless_workgroup" "analytics" {
  count              = var.enable_redshift_serverless ? 1 : 0
  namespace_name     = aws_redshiftserverless_namespace.analytics[0].namespace_name
  workgroup_name     = local.redshift_workgroup_name
  base_capacity      = var.redshift_base_capacity
  subnet_ids         = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.redshift[0].id]
  publicly_accessible = false
  enhanced_vpc_routing = true
}