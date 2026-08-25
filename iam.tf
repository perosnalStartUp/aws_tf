# =============================================================================
# IAM and GitHub OIDC inputs
# =============================================================================
variable "github_organization" {
  type        = string
  description = "GitHub organization that owns the approved workflow repositories."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_organization))
    error_message = "github_organization must be a valid GitHub organization name."
  }
}

variable "github_repositories" {
  type = object({
    terraform = string
    backend   = string
    gpu       = string
  })
  description = "Repository names for Terraform, Backend, and GPU workflow ownership."
  nullable    = false

  validation {
    condition = alltrue([
      for repository in values(var.github_repositories) :
      can(regex("^[A-Za-z0-9._-]{1,100}$", repository))
    ])
    error_message = "Each github_repositories value must be a non-empty GitHub repository name."
  }
}

variable "github_oidc_subjects" {
  type = object({
    terraform        = set(string)
    backend_packer   = set(string)
    backend_release  = set(string)
    training_packer  = set(string)
    training_release = set(string)
  })
  description = "Exact approved GitHub OIDC subject claims for each workflow role."
  nullable    = false

  validation {
    condition = (
      length(var.github_oidc_subjects.terraform) > 0 &&
      length(var.github_oidc_subjects.backend_packer) > 0 &&
      length(var.github_oidc_subjects.backend_release) > 0 &&
      length(var.github_oidc_subjects.training_packer) > 0 &&
      length(var.github_oidc_subjects.training_release) > 0 &&
      alltrue([
        for subject in var.github_oidc_subjects.terraform :
        startswith(subject, "repo:${var.github_organization}/${var.github_repositories.terraform}:") &&
        !strcontains(subject, "*")
      ]) &&
      alltrue([
        for subject in setunion(
          var.github_oidc_subjects.backend_packer,
          var.github_oidc_subjects.backend_release,
        ) :
        startswith(subject, "repo:${var.github_organization}/${var.github_repositories.backend}:") &&
        !strcontains(subject, "*")
      ]) &&
      alltrue([
        for subject in setunion(
          var.github_oidc_subjects.training_packer,
          var.github_oidc_subjects.training_release,
        ) :
        startswith(subject, "repo:${var.github_organization}/${var.github_repositories.gpu}:") &&
        !strcontains(subject, "*")
      ])
    )
    error_message = "Every workflow role must use non-wildcard subjects under its exact approved repository."
  }
}

variable "working_auth_secret_arn" {
  type        = string
  description = "Approved external Secrets Manager ARN for Working authentication."
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$", var.working_auth_secret_arn))
    error_message = "working_auth_secret_arn must be a Secrets Manager secret ARN."
  }
}

variable "training_callback_secret_arn" {
  type        = string
  description = "Single approved Secrets Manager ARN for Training callback authentication."
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$", var.training_callback_secret_arn))
    error_message = "training_callback_secret_arn must be a Secrets Manager secret ARN."
  }
}

# =============================================================================
# GitHub OIDC provider
# =============================================================================
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# =============================================================================
# Workflow and runtime roles
# =============================================================================
locals {
  workflow_subjects = {
    terraform        = var.github_oidc_subjects.terraform
    backend_packer   = var.github_oidc_subjects.backend_packer
    backend_release  = var.github_oidc_subjects.backend_release
    training_packer  = var.github_oidc_subjects.training_packer
    training_release = var.github_oidc_subjects.training_release
  }

  workflow_role_names = {
    terraform        = "${local.name_prefix}-terraform-deploy"
    backend_packer   = "${local.name_prefix}-backend-packer"
    backend_release  = "${local.name_prefix}-backend-release"
    training_packer  = "${local.name_prefix}-training-packer"
    training_release = "${local.name_prefix}-training-release"
  }

  workflow_repositories = {
    terraform        = "${var.github_organization}/${var.github_repositories.terraform}"
    backend_packer   = "${var.github_organization}/${var.github_repositories.backend}"
    backend_release  = "${var.github_organization}/${var.github_repositories.backend}"
    training_packer  = "${var.github_organization}/${var.github_repositories.gpu}"
    training_release = "${var.github_organization}/${var.github_repositories.gpu}"
  }
}

resource "aws_iam_role" "workflow" {
  for_each = local.workflow_subjects

  name = local.workflow_role_names[each.key]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = sort(tolist(each.value))
        }
      }
    }]
  })

  tags = {
    WorkflowRepository = local.workflow_repositories[each.key]
  }
}

locals {
  runtime_role_names = {
    backend  = "${local.name_prefix}-backend-runtime"
    working  = "${local.name_prefix}-working-runtime"
    training = "${local.name_prefix}-training-runtime"
  }
}

resource "aws_iam_role" "runtime" {
  for_each = local.runtime_role_names

  name = each.value
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "runtime" {
  for_each = aws_iam_role.runtime

  name = each.value.name
  role = each.value.name
}

locals {
  backend_runtime_role  = aws_iam_role.runtime["backend"]
  working_runtime_role  = aws_iam_role.runtime["working"]
  training_runtime_role = aws_iam_role.runtime["training"]
  terraform_deploy_role = aws_iam_role.workflow["terraform"]
  backend_packer_role   = aws_iam_role.workflow["backend_packer"]
  backend_release_role  = aws_iam_role.workflow["backend_release"]
  training_packer_role  = aws_iam_role.workflow["training_packer"]
  training_release_role = aws_iam_role.workflow["training_release"]
}

# =============================================================================
# Terraform deployment policy
# =============================================================================
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
    [aws_iam_role.vpc_flow_logs.arn],
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
          "budgets:*",
          "ce:*",
          "cloudwatch:*",
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
          aws_kms_key.observability.arn,
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
          [aws_iam_role.vpc_flow_logs.arn],
        )
      },
    ]
  })
}

# =============================================================================
# Runtime policies
# =============================================================================
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

# =============================================================================
# Packer and release policies
# =============================================================================
locals {
  packer_actions = [
    "ec2:AttachVolume",
    "ec2:CreateImage",
    "ec2:CreateSnapshot",
    "ec2:CreateTags",
    "ec2:DeleteSnapshot",
    "ec2:DeregisterImage",
    "ec2:DescribeImages",
    "ec2:DescribeInstances",
    "ec2:DescribeInstanceStatus",
    "ec2:DescribeRegions",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSnapshots",
    "ec2:DescribeSubnets",
    "ec2:DescribeVolumes",
    "ec2:DetachVolume",
    "ec2:RunInstances",
    "ec2:StopInstances",
    "ec2:TerminateInstances",
  ]
}

resource "aws_iam_role_policy" "packer" {
  for_each = {
    backend  = local.backend_packer_role
    training = local.training_packer_role
  }

  name = "${each.key}-packer"
  role = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = local.packer_actions
      Resource = "*"
      Condition = {
        StringEqualsIfExists = {
          "aws:RequestedRegion" = var.aws_region
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "backend_release" {
  name = "backend-ami-release"
  role = local.backend_release_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadReleaseState"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeInstanceRefreshes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates",
        ]
        Resource = "*"
        Condition = {
          StringEqualsIfExists = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "UpdateBackendLaunchTemplate"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifyLaunchTemplate",
        ]
        Resource = aws_launch_template.backend.arn
        Condition = {
          StringEqualsIfExists = {
            "aws:ResourceTag/Component" = "backend"
          }
        }
      },
      {
        Sid    = "RollBackendAutoScalingGroup"
        Effect = "Allow"
        Action = [
          "autoscaling:CancelInstanceRefresh",
          "autoscaling:RollbackInstanceRefresh",
          "autoscaling:StartInstanceRefresh",
        ]
        Resource = aws_autoscaling_group.backend.arn
      },
    ]
  })
}

resource "aws_iam_role_policy" "training_release" {
  name = "training-ami-release"
  role = local.training_release_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLaunchTemplates"
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates",
        ]
        Resource = "*"
        Condition = {
          StringEqualsIfExists = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "UpdateTrainingLaunchTemplate"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifyLaunchTemplate",
        ]
        Resource = aws_launch_template.training.arn
        Condition = {
          StringEqualsIfExists = {
            "aws:ResourceTag/Component" = "training"
          }
        }
      },
    ]
  })
}

# =============================================================================
# IAM outputs
# =============================================================================
output "workflow_role_arns" {
  description = "OIDC workflow role ARNs keyed by deployment/build/release boundary."
  value       = { for name, role in aws_iam_role.workflow : name => role.arn }
}

output "runtime_role_arns" {
  description = "Runtime IAM role ARNs keyed by component."
  value       = { for name, role in aws_iam_role.runtime : name => role.arn }
}

output "runtime_instance_profile_names" {
  description = "Runtime instance profile names keyed by component."
  value       = { for name, profile in aws_iam_instance_profile.runtime : name => profile.name }
}
