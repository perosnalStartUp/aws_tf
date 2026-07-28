# Terraform AWS Hard Limits

These limits apply unless the user explicitly approves a documented architecture change. A local
implementation convenience is not sufficient reason to bypass them.

## Network and Compute

- Backend, Working, Training, and RDS must not receive public IP addresses.
- Do not expose SSH to the internet. Prefer SSM Session Manager for controlled access.
- Only the public ALB may accept internet ingress for the backend.
- Working accepts application traffic only from the backend security group on its confirmed
  service port.
- Training has no public application listener; it consumes SQS and calls approved AWS/backend
  endpoints.
- Require IMDSv2 and encrypt EBS volumes.
- Working V0 must remain one private EC2 and must not silently acquire a Launch Template, ASG, or
  ALB.
- Training initial capacity is On-Demand. Spot is prohibited until interruption/resume behavior is
  verified on AWS and separately approved.

## AMI, Launch Template, and ASG

- Do not discover production AMIs through “latest by name” or `most_recent`.
- Do not use mutable container image tags as deployment identity.
- For Backend and Training, Terraform owns Launch Template/ASG structure while the release workflow
  owns AMI-only versions, `$Default`, and rollout actions.
- A release workflow must clone from `$Default`, never blindly from `$Latest`.
- A release workflow must reject a candidate version if anything except `ImageId` differs from the
  source version.
- Backend rollout may use Instance Refresh. Training rollout must not force-refresh or terminate
  protected in-flight workers.
- On release failure, restore the prior `$Default` pointer and report actual instance AMI and
  Launch Template versions. Pointer rollback alone is not proof of fleet rollback.
- Serialize releases for each component; concurrent pointer updates are prohibited.

## Identity, Data, and Secrets

- Use GitHub OIDC for workflows. Do not create or document long-lived AWS access keys.
- Avoid wildcard actions and resources when AWS supports a narrower scope.
- Runtime roles must be separate for Backend, Working, and Training.
- Build, release, Terraform deploy, and runtime permissions must not be combined into one role.
- Never put secret values, database passwords, API keys, or callback tokens in Git, Terraform
  state, plan artifacts, user data, AMIs, container images, or logs.
- Product S3 objects and SQS queues must use approved KMS encryption.
- RDS credentials must be managed by an approved secret mechanism and consumed at runtime.
- Training must not connect directly to RDS.
- Do not delete datasets, adapters, checkpoints, state, backups, AMIs, snapshots, or log archives
  without an explicit retention/deletion decision.

## Terraform and Delivery

- Do not run `apply`, `destroy`, state mutation, import, force-unlock, Packer build, workflow
  dispatch, or AWS mutation without explicit authorization and a named environment.
- Do not use `-target` as a normal deployment strategy.
- Do not hide unresolved architecture decisions behind defaults.
- Do not check in `.terraform/`, plan files, state files, crash logs, or local secret variable files.
- Pin action revisions, module versions, provider constraints, base images, and production container
  digests once selected.
- Database migrations run once as a release step; they must not race from every backend ASG
  instance at startup.
- A task is not “deployed,” “verified,” or “production ready” unless the corresponding action
  actually ran and evidence is recorded.
