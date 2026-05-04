resource "aws_sqs_queue" "dead_letter" {
  name                       = local.dlq_name
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds
}

resource "aws_sqs_queue" "jobs" {
  name                              = local.queue_name
  visibility_timeout_seconds        = var.queue_visibility_timeout_seconds
  message_retention_seconds         = 345600
  receive_wait_time_seconds         = var.queue_receive_wait_time_seconds
  sqs_managed_sse_enabled           = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = 5
  })
}