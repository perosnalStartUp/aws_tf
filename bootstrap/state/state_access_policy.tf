resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowStateBucketMetadata"
        Effect = "Allow"
        Principal = {
          AWS = sort(tolist(var.state_access_principal_arns))
        }
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
        ]
        Resource = aws_s3_bucket.state.arn
      },
      {
        Sid    = "AllowStateAndLockObjects"
        Effect = "Allow"
        Principal = {
          AWS = sort(tolist(var.state_access_principal_arns))
        }
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = local.state_object_arns
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}
