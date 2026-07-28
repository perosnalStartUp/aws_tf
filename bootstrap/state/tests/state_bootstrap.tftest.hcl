mock_provider "aws" {}

variables {
  project_name                       = "personal-lora"
  aws_region                         = "us-east-1"
  aws_account_id                     = "123456789012"
  state_bucket_name                  = "personal-lora-test-terraform-state"
  state_kms_key_deletion_window_days = 30
  state_access_principal_arns = [
    "arn:aws:iam::123456789012:role/terraform-test",
  ]
  owner       = "local-test"
  cost_center = "N/A"
}

run "plans_hardened_state_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "personal-lora-test-terraform-state"
    error_message = "The State bucket must use the explicit input name."
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket versioning must remain enabled."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.state.restrict_public_buckets
    error_message = "State bucket public access must remain fully blocked."
  }

  assert {
    condition = (
      length(aws_s3_bucket_server_side_encryption_configuration.state.rule) == 1 &&
      alltrue(flatten([
        for encryption_rule in aws_s3_bucket_server_side_encryption_configuration.state.rule : [
          for default_encryption in encryption_rule.apply_server_side_encryption_by_default :
          default_encryption.sse_algorithm == "aws:kms"
        ]
      ]))
    )
    error_message = "State bucket customer-managed KMS encryption must remain enabled."
  }

  assert {
    condition     = aws_kms_key.state.enable_key_rotation
    error_message = "The Terraform-managed State KMS key must keep automatic rotation enabled."
  }
}

run "rejects_invalid_state_bucket_name" {
  command = plan

  variables {
    state_bucket_name = "INVALID_BUCKET_NAME"
  }

  expect_failures = [
    var.state_bucket_name,
  ]
}

run "rejects_empty_access_principals" {
  command = plan

  variables {
    state_access_principal_arns = []
  }

  expect_failures = [
    var.state_access_principal_arns,
  ]
}
