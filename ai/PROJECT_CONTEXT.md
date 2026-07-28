# Personal LoRA Terraform Project Context

## System

Personal LoRA lets users submit datasets, train LoRA adapters, and use completed adapters for
inference. AWS infrastructure connects three server-side components:

1. Backend: public API/business control plane, running privately behind an ALB.
2. GPU Training: SQS-driven ephemeral workers that produce adapters, checkpoints, and logs.
3. GPU Working: private inference runtime that loads approved adapters from S3.

The Vercel frontend calls the backend and is not deployed by this repository.

## Repository Boundaries

| Repository | Responsibility relevant to Terraform |
| --- | --- |
| `backend` | API, database access, job creation/status, SQS producer, callbacks, Working client |
| `gpu_ec2` | Working and Training runtime, AMI/container packaging, instance lifecycle behavior |
| `terraform` | AWS topology, IAM, data services, compute resources, monitoring, and release integration |
| `front-end` | Vercel UI; consumes the backend public API |

Cross-repository changes must be reflected in the owning repository's design and development
records. Terraform documentation does not override a runtime contract by itself.

## Current Factual Snapshot — 2026-07-28

- This Terraform repository was an empty Git repository on branch `vpc` with no commits before the
  control-document initialization.
- Terraform foundation, State-bootstrap, network/private DNS, security-group graph, product
  KMS/S3, single-NAT, and S3 Gateway Endpoint configuration now exist locally with mock-provider
  tests; no Terraform State, live plan, apply, AWS resource, Packer build, or deployment has been
  created or verified from this repository.
- Working local application work is recorded in the GPU repository, but a real Working AMI and AWS
  deployment are not verified.
- Training local runtime/container/systemd work is recorded in the GPU repository, but a real
  Training AMI, GPU run, and AWS deployment are not verified.
- Backend contains existing deployment experiments and in-progress integration work. Those files
  are reference material, not proof that this new Terraform design has been deployed.

## Status Vocabulary

- **Planned**: accepted scope with no implementation evidence.
- **Implemented locally**: files exist and relevant local checks passed.
- **Built**: an immutable artifact was actually produced and identified.
- **Deployed**: live resources were changed in a named environment.
- **Verified**: recorded evidence confirms the intended behavior in the relevant environment.
- **Blocked**: a required external decision or dependency prevents safe progress.

Never promote a status without evidence in `routeMap/TERRAFORM_DEV_DOC.md`.
