---
name: terraform-aws-development
description: Design, implement, review, validate, and document the Personal LoRA AWS Terraform platform. Use for Terraform files, VPC/network topology, IAM, security groups, KMS, S3, SQS, RDS, Route53, ALB, EC2, Launch Templates, Auto Scaling Groups, state/bootstrap, Packer/AMI handoff, GitHub release workflows, observability, cost/security reviews, and related architecture or development records.
---

# Terraform AWS Development

## Purpose

Develop the shared AWS platform without blurring infrastructure ownership, application contracts,
or live-deployment authorization. Preserve evidence-backed status and coordinate changes with the
Backend, GPU Working, and GPU Training repositories.

## Load Context

Before acting, read the repository root `AGENTS.md` and every document it marks as required.
Always load `references/RESTRICTS.md`. For a cross-repository contract change, also read the
consumer repository's root instructions and relevant design/dev documents.

Inspect the current branch, worktree, existing Terraform layout, and factual development record.
Preserve unrelated user changes.

## Classify the Task

Determine which surfaces are affected:

- state/bootstrap;
- network/DNS/security groups;
- data services and encryption;
- IAM and GitHub OIDC;
- Backend compute/ALB/RDS;
- Working V0 single instance;
- Training ASG/SQS/lifecycle/scaling;
- AMI build/release integration;
- monitoring, budgets, or operations;
- documentation only.

If an input is undecided, mark it `[DECISION REQUIRED]`. Do not create a convenient production
default that silently resolves an architecture choice.

## Implement Safely

1. Keep Terraform's resource ownership consistent with `BASE_SETTINGS.md`.
2. Use exact approved AMI IDs and immutable artifact identities.
3. Keep Backend/Training AMI-only release mutations inside the documented `$Default` pointer
   boundary.
4. Keep Working V0 as one Terraform-managed private EC2 without LT/ASG/ALB.
5. Use least-privilege runtime, build, release, and deploy identities.
6. Keep secrets out of Terraform state, plans, user data, logs, and artifacts.
7. Add variable validation, lifecycle preconditions/checks, and explicit comments where ownership
   is intentionally split.
8. Do not modify live AWS resources unless the user explicitly authorizes the action and
   environment.

## Validate

Use checks appropriate to the files that actually exist:

- `terraform fmt -check -recursive`;
- `terraform init -backend=false` and `terraform validate` when initialization is safe;
- repository-configured lint, security, or policy checks;
- deterministic tests for helper scripts or policies;
- `git diff --check` and focused review of IAM, lifecycle, and destructive behavior.

Do not claim `plan`, `apply`, AMI build, deployment, or AWS verification when it did not run. A
live `terraform plan` also requires explicit authorization because it consumes credentials and
reads a named environment.

## Record the Result

Before completing material work:

- update `routeMap/TERRAFORM_DEV_DOC.md`;
- update `routeMap/TERRAFORM_AWS_DESIGN.md` for architecture/ownership decisions;
- update `routeMap/AMI_ASG_RELEASE_DESIGN.md` for AMI/LT/ASG/rollout decisions;
- update `routeMap/TERRAFORM_P1_ROADMAP.md` when milestone status or blockers change;
- record exact commands and honest results, using `not run` where applicable.

Report files changed, validation performed, remaining blockers, and whether live AWS was untouched.
