locals {
  terraform_pass_role_arns = concat(
    [for role in values(aws_iam_role.runtime) : role.arn],
    [
      local.backend_packer_role.arn,
      local.backend_release_role.arn,
      local.training_packer_role.arn,
      local.training_release_role.arn,
    ],
    aws_iam_role.rds_monitoring[*].arn,
  )
}

resource "aws_iam_role_policy" "terraform_deploy" {
  name = "environment-deploy"
  role = local.terraform_deploy_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnvironmentInfrastructure"
        Effect = "Allow"
        Action = [
          "autoscaling:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "logs:*",
          "rds:*",
          "route53:ChangeResourceRecordSets",
          "route53:ChangeTagsForResource",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "secretsmanager:DescribeSecret",
          "sqs:*",
        ]
        Resource = "*"
        Condition = {
          StringEqualsIfExists = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid      = "CreateTaggedEnvironmentKeys"
        Effect   = "Allow"
        Action   = "kms:CreateKey"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
            "aws:RequestedRegion"        = var.aws_region
          }
        }
      },
      {
        Sid    = "ManageProductAndQueueKeys"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:DisableKeyRotation",
          "kms:EnableKeyRotation",
          "kms:GetKeyPolicy",
          "kms:ListResourceTags",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:UpdateAlias",
          "kms:UpdateKeyDescription",
        ]
        Resource = [
          aws_kms_key.product.arn,
          aws_kms_key.training_queue.arn,
          aws_kms_key.database.arn,
        ]
      },
      {
        Sid    = "ManageProductBucket"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          aws_s3_bucket.product.arn,
          "${aws_s3_bucket.product.arn}/*",
        ]
      },
      {
        Sid      = "PassOnlyEnvironmentRoles"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = local.terraform_pass_role_arns
      },
      {
        Sid    = "ManageEnvironmentIAM"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:CreateOpenIDConnectProvider",
          "iam:CreatePolicy",
          "iam:CreatePolicyVersion",
          "iam:CreateRole",
          "iam:DeleteInstanceProfile",
          "iam:DeleteOpenIDConnectProvider",
          "iam:DeletePolicy",
          "iam:DeletePolicyVersion",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetInstanceProfile",
          "iam:GetOpenIDConnectProvider",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:PutRolePolicy",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:TagRole",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagRole",
          "iam:UntagOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:UpdateAssumeRolePolicy",
        ]
        Resource = concat(
          [for role in values(aws_iam_role.runtime) : role.arn],
          [for role in values(aws_iam_role.workflow) : role.arn],
          [
            "arn:aws:iam::${var.aws_account_id}:instance-profile/${local.name_prefix}-*",
            "arn:aws:iam::${var.aws_account_id}:policy/${local.name_prefix}-*",
            aws_iam_openid_connect_provider.github.arn,
          ],
          aws_iam_role.rds_monitoring[*].arn,
        )
      },
    ]
  })
}
