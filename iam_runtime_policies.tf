resource "aws_iam_role_policy" "runtime_product_data" {
  for_each = aws_iam_role.runtime

  name   = "product-data"
  role   = each.value.id
  policy = local.product_s3_component_policy_json[each.key]
}

resource "aws_iam_role_policy" "backend_integrations" {
  name = "backend-integrations"
  role = local.backend_runtime_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendTrainingJobs"
        Effect   = "Allow"
        Action   = ["sqs:GetQueueUrl", "sqs:SendMessage"]
        Resource = aws_sqs_queue.training.arn
      },
      {
        Sid    = "UseTrainingQueueKMS"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:GenerateDataKey",
        ]
        Resource = aws_kms_key.training_queue.arn
      },
      {
        Sid    = "ReadDatabaseCredential"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
        ]
        Resource = one(aws_db_instance.postgres.master_user_secret).secret_arn
      },
      {
        Sid      = "DecryptDatabaseCredential"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = aws_kms_key.database.arn
      },
    ]
  })
}

resource "aws_iam_role_policy" "working_secret" {
  name = "working-auth-secret"
  role = local.working_runtime_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
      ]
      Resource = var.working_auth_secret_arn
    }]
  })
}

resource "aws_iam_role_policy" "training_integrations" {
  name = "training-integrations"
  role = local.training_runtime_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ConsumeTrainingJobs"
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.training.arn
      },
      {
        Sid      = "DecryptTrainingQueue"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = aws_kms_key.training_queue.arn
      },
      {
        Sid    = "ReadCallbackSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
        ]
        Resource = var.training_callback_secret_arn
      },
      {
        Sid    = "ManageOwnLifecycle"
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:RecordLifecycleActionHeartbeat",
          "autoscaling:SetInstanceProtection",
        ]
        Resource = aws_autoscaling_group.training.arn
      },
      {
        Sid      = "DiscoverOwnAutoScalingMembership"
        Effect   = "Allow"
        Action   = ["autoscaling:DescribeAutoScalingInstances"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "runtime_logging" {
  for_each = aws_iam_role.runtime

  name = "runtime-logging"
  role = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.runtime[each.key].arn}:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "runtime_ssm" {
  for_each = aws_iam_role.runtime

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
