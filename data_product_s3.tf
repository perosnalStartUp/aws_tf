resource "aws_s3_bucket" "product" {
  bucket = var.product_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "product" {
  bucket = aws_s3_bucket.product.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "product" {
  bucket = aws_s3_bucket.product.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "product" {
  bucket = aws_s3_bucket.product.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "product" {
  bucket = aws_s3_bucket.product.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.product.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
