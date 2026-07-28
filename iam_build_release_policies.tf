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
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*"
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
        Resource = "arn:aws:autoscaling:${var.aws_region}:${var.aws_account_id}:autoScalingGroup:*:autoScalingGroupName/${var.backend_asg_name}"
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
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*"
        Condition = {
          StringEqualsIfExists = {
            "aws:ResourceTag/Component" = "training"
          }
        }
      },
    ]
  })
}
