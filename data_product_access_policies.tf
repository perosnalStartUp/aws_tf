locals {
  product_s3_component_policy_json = {
    for component, access in var.product_s3_component_access : component => jsonencode({
      Version = "2012-10-17"
      Statement = concat(
        [{
          Sid      = "ListApprovedPrefixes"
          Effect   = "Allow"
          Action   = ["s3:ListBucket"]
          Resource = aws_s3_bucket.product.arn
          Condition = {
            StringLike = {
              "s3:prefix" = flatten([
                for prefix in sort(tolist(setunion(access.read_prefixes, access.write_prefixes))) :
                [prefix, "${prefix}/*"]
              ])
            }
          }
        }],
        length(setunion(access.read_prefixes, access.write_prefixes)) > 0 ? [{
          Sid    = "ReadApprovedPrefixes"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
          ]
          Resource = [
            for prefix in sort(tolist(setunion(access.read_prefixes, access.write_prefixes))) :
            "${aws_s3_bucket.product.arn}/${prefix}/*"
          ]
        }] : [],
        length(access.write_prefixes) > 0 ? [{
          Sid    = "WriteApprovedPrefixes"
          Effect = "Allow"
          Action = [
            "s3:AbortMultipartUpload",
            "s3:DeleteObject",
            "s3:PutObject",
          ]
          Resource = [
            for prefix in sort(tolist(access.write_prefixes)) :
            "${aws_s3_bucket.product.arn}/${prefix}/*"
          ]
        }] : [],
        [{
          Sid    = "UseProductKMSKey"
          Effect = "Allow"
          Action = concat(
            ["kms:Decrypt", "kms:DescribeKey"],
            length(access.write_prefixes) > 0 ? [
              "kms:Encrypt",
              "kms:GenerateDataKey",
              "kms:ReEncryptFrom",
              "kms:ReEncryptTo",
            ] : [],
          )
          Resource = aws_kms_key.product.arn
        }],
      )
    })
  }
}
