locals {
  s3_gateway_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ApprovedProductBucketsOnly"
      Effect    = "Allow"
      Principal = "*"
      Action = [
        "s3:DeleteObject",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject",
      ]
      Resource = [
        aws_s3_bucket.product.arn,
        "${aws_s3_bucket.product.arn}/*",
      ]
    }]
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.private_application : route_table.id]
  policy            = local.s3_gateway_endpoint_policy

  tags = {
    Name = "${local.name_prefix}-s3"
  }
}
