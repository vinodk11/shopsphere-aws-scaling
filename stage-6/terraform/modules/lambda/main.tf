# ==============================================================================
# Lambda Module — Stage 5 Serverless Asynchronous Worker
# Consumes SQS Order Events, Processes Background Fulfillment, Logs to CloudWatch
# ==============================================================================

locals {
  resolved_function_name = var.function_name != "" ? var.function_name : "${var.project_name}-${var.environment}-order-processor"
}

# ------------------------------------------------------------------------------
# 1. Package Lambda Function Source Code
# ------------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/order_processor_payload.zip"
}

# ------------------------------------------------------------------------------
# 2. CloudWatch Log Group for Lambda Worker
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.resolved_function_name}"
  retention_in_days = var.log_retention_in_days

  tags = merge(
    var.tags,
    {
      Name = "/aws/lambda/${local.resolved_function_name}"
      Tier = "Observability-CloudWatch"
    }
  )
}

# ------------------------------------------------------------------------------
# 3. AWS Lambda Function
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "order_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = local.resolved_function_name
  role             = var.lambda_role_arn
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = var.environment_variables
  }

  tags = merge(
    var.tags,
    {
      Name = local.resolved_function_name
      Tier = "Serverless-Worker"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# ------------------------------------------------------------------------------
# 4. SQS Event Source Mapping Trigger
# ------------------------------------------------------------------------------
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.order_processor.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.maximum_batching_window_in_seconds
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true
}
