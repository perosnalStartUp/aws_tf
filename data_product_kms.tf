resource "aws_kms_key" "product" {
  description             = "Product data encryption for ${local.name_prefix}"
  deletion_window_in_days = var.product_kms_key_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableAccountIAMPermissions"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.aws_account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "product" {
  name          = "alias/${local.name_prefix}-product"
  target_key_id = aws_kms_key.product.key_id
}
