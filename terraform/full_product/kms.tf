resource "aws_kms_key" "artifacts" {
  description             = "KMS key for ${local.name_prefix} artifact encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "artifacts" {
  name          = "alias/${local.name_prefix}-artifacts"
  target_key_id = aws_kms_key.artifacts.key_id
}