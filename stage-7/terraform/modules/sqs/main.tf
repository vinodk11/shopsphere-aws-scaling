# ==============================================================================
# SQS Module — Stage 5 Asynchronous Decoupled Message Queues
# Main Order Queue + Dead Letter Queue (DLQ) with Redrive Policy
# ==============================================================================

locals {
  resolved_queue_name = var.queue_name != "" ? var.queue_name : "${var.project_name}-${var.environment}-order-processing-queue"
  resolved_dlq_name   = var.dlq_name != "" ? var.dlq_name : "${var.project_name}-${var.environment}-order-processing-dlq"
}

# ------------------------------------------------------------------------------
# 1. Dead Letter Queue (DLQ) for Failed Order Messages
# ------------------------------------------------------------------------------
resource "aws_sqs_queue" "dlq" {
  name                      = local.resolved_dlq_name
  message_retention_seconds = var.dlq_message_retention_seconds
  sqs_managed_sse_enabled   = var.sqs_managed_sse_enabled
  kms_master_key_id         = var.kms_master_key_id

  tags = merge(
    var.tags,
    {
      Name = local.resolved_dlq_name
      Type = "DeadLetterQueue"
      Tier = "Messaging-SQS"
    }
  )
}

# ------------------------------------------------------------------------------
# 2. Main Order Processing Queue with Redrive Policy
# ------------------------------------------------------------------------------
resource "aws_sqs_queue" "main" {
  name                       = local.resolved_queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  sqs_managed_sse_enabled    = var.sqs_managed_sse_enabled
  kms_master_key_id          = var.kms_master_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(
    var.tags,
    {
      Name = local.resolved_queue_name
      Type = "MainOrderQueue"
      Tier = "Messaging-SQS"
    }
  )
}

# ------------------------------------------------------------------------------
# 3. DLQ Redrive Allow Policy (Restricting DLQ access to the main queue)
# ------------------------------------------------------------------------------
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}
