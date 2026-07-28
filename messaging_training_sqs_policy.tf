resource "aws_sqs_queue_policy" "training" {
  queue_url = aws_sqs_queue.training.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "BackendSend"
        Effect    = "Allow"
        Principal = { AWS = local.backend_runtime_role.arn }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.training.arn
      },
      {
        Sid       = "TrainingConsume"
        Effect    = "Allow"
        Principal = { AWS = local.training_runtime_role.arn }
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.training.arn
      },
    ]
  })
}
