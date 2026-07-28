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
