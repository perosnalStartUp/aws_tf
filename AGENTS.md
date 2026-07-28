# AGENTS.md — Personal LoRA Terraform Repository

## Required Reading

Before changing Terraform, AWS topology, IAM, security groups, state, AMI release integration,
Launch Templates, Auto Scaling Groups, workflows, or related documentation, read these files in
full:

1. `ai/BASE_SETTINGS.md`
2. `ai/LIMITS.md`
3. `ai/PROJECT_CONTEXT.md`
4. `ai/INTEGRATION_CONTRACTS.md`
5. `ai/terraform-aws-development/SKILL.md`
6. `ai/terraform-aws-development/references/RESTRICTS.md`
7. `routeMap/TERRAFORM_AWS_DESIGN.md`
8. `routeMap/AMI_ASG_RELEASE_DESIGN.md`
9. `routeMap/TERRAFORM_DEV_DOC.md`
10. `routeMap/TERRAFORM_P1_ROADMAP.md`
11. `routeMap/TERRAFORM_P1_TASKS.md`
12. `routeMap/BACKEND_MIGRATION_RUNBOOK.md`
12. `routeMap/TERRAFORM_P1_PR_PLAN.md`

When a task changes a consuming service contract, also read that service repository's root
`AGENTS.md` and the referenced design/dev documents before implementation.

## Mandatory Development Record

Any task that materially changes code, configuration, Terraform, Packer, workflows, runtime
behavior, security boundaries, or architecture must update `routeMap/TERRAFORM_DEV_DOC.md` before
the task is reported complete.

- Architecture and ownership decisions also update `routeMap/TERRAFORM_AWS_DESIGN.md`.
- AMI, Launch Template, ASG, or rollout decisions also update
  `routeMap/AMI_ASG_RELEASE_DESIGN.md`.
- Milestone or dependency changes also update `routeMap/TERRAFORM_P1_ROADMAP.md`.
- Detailed task dependency/status changes also update `routeMap/TERRAFORM_P1_TASKS.md`.
- Read-only investigation does not update a dev doc unless it discovers a factual status change or
  the user explicitly requests a record.

Never invent a branch, commit, PR, deployment, test result, plan result, performance number, or AWS
resource. Use `N/A`, `not created`, `not run`, or `[ASSUMPTION]` when that is the truth.

## Execution Boundary

Repository edits and local static validation are within normal development scope. The following
actions require explicit user authorization and an identified environment:

- `terraform plan` against live credentials;
- `terraform apply`, `destroy`, `import`, state mutation, or force-unlock;
- Packer builds or AMI deletion;
- GitHub workflow dispatch or mutation;
- AWS API/CLI mutations.

Do not treat permission to edit Terraform as permission to change live AWS resources.
