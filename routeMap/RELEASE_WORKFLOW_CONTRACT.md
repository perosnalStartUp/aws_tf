# Release Workflow Contract and Activation Gates

## Repository Ownership

| Workflow | Owning repository | Terraform repository responsibility |
| --- | --- | --- |
| Terraform validate/plan/apply and Working replacement | `terraform` | root configuration, deploy role, backend/input contract and review evidence |
| Backend Packer and Backend AMI release | `small_backend` | Backend LT/ASG resources, narrow release role/policy and resource outputs |
| Working/Training Packer and Training AMI release | `gpu_ec2` | Working input contract; Training LT/ASG resources, narrow release role/policy and outputs |

This repository must not create the Backend or Training workflow files. PR24/25 remain external
repository changes. Their roles are structurally present here, but activation remains blocked by
the unresolved field-ownership wording and real artifact/runtime evidence.

## Resource Reference Rule

When a resource exists in this Terraform root, policies, outputs and dependent resources reference
its provider attribute directly, for example:

```hcl
kms_master_key_id = aws_kms_key.product.arn
resource           = aws_s3_bucket.product.arn
```

Hand-written/mock ARNs are allowed only inside deterministic tests or for an intentionally external
resource such as an owner-managed SNS topic or secret. If a later PR creates that resource in this
root, the input is replaced by the direct resource reference.

## Working Release Workflow (`terraform`)

The future executable workflow is `workflow_dispatch` only and must use:

- a GitHub Environment that identifies one approved AWS account/region/environment;
- OIDC with the exact Terraform deploy subject and no long-lived AWS access key;
- read-only repository permission plus `id-token: write`;
- concurrency keyed by account, region, environment and `working`;
- an immutable, exact candidate AMI ID and build-evidence reference;
- protected real backend configuration and complete reviewed environment variables;
- a plan phase separated from an approval-gated apply phase;
- apply of the exact reviewed saved plan, never a newly generated plan;
- evidence listed in `SERVICE_VALIDATION_RUNBOOK.md`.

It must fail closed if the branch/ref, OIDC subject, expected Account ID, region, environment,
candidate AMI evidence, backend configuration, full variable set, saved-plan digest, or approval is
missing. It must not call Launch Template or Auto Scaling APIs because Working V0 is a direct
Terraform-owned EC2 replacement.

An executable workflow file is not created yet because `DEC-012` still lacks the real environment
name, exact GitHub Environment approval rule, backend-config delivery method, complete real
variable delivery method, and protected plan-artifact policy. Choosing those values silently would
create a deployment/security contract rather than complete a local implementation.

## Backend and Training Release Workflows

Both external workflows must:

1. consume an immutable Packer manifest with AMI ID, owner account, region, component, architecture,
   source commit, build run, container digest when applicable, and checks performed;
2. assume only the component/environment release role through exact OIDC claims;
3. serialize by account/region/environment/component;
4. read the current LT `$Default`, clone that version, and change only `ImageId`;
5. compare the full semantic LT data and reject every non-ImageId difference;
6. re-read `$Default` immediately before promotion and fail on a stale base;
7. promote the new LT version to `$Default`;
8. collect the prior/new default, version, AMI and instance evidence.

Backend then starts the reviewed Instance Refresh and proves ALB/application health or restores the
prior pointer and records actual fleet state. Training does not start a routine Instance Refresh,
terminate workers, or remove scale-in protection; it proves that new scale-outs use the promoted
default while protected workers drain naturally.

## Release Hardening and Drift Matrix

| Case | Expected Terraform/release result | Evidence boundary |
| --- | --- | --- |
| No external release | Terraform plan is no-op when configuration and infrastructure match. | live nonproduction plan required |
| AMI-only external release | Terraform does not reset Backend/Training `image_id` or `$Default`; unrelated structure remains checked. | external workflow plus live plan required |
| Structural drift | Terraform detects and proposes correction for Terraform-owned LT/ASG fields. | controlled nonproduction drift required |
| Structural update after release | New Terraform LT structure retains the approved current release AMI before any later promotion. | governance/workflow implementation plus live test required |
| Concurrent release | component/environment concurrency prevents overlap. | external GitHub workflow test required |
| Stale default | compare-before-promote fails without changing `$Default`. | external GitHub workflow test required |
| Backend rollback | pointer and real fleet/ALB/application state are recorded separately. | nonproduction refresh failure exercise required |
| Training rollback | pointer restoration does not claim protected mixed-version workers changed. | nonproduction scale/lifecycle exercise required |
| Working rollback | prior exact AMI produces a second reviewed Terraform replacement and DNS update. | authorized plan/apply required |

Local Mock tests can validate inputs and Terraform resource relationships, but they cannot prove AWS
LT pointer behavior, Instance Refresh, protected workers, DNS propagation, OIDC claims, workflow
concurrency, or real drift. Those are PR29/30 evidence, not local claims.

## Activation Checklist

- [ ] `DEC-011` exact refs/environments/approval rules confirmed.
- [ ] `DEC-012` Terraform backend, variable and saved-plan handling confirmed.
- [ ] `EXT-01` Backend/Training message/callback/control contract aligned.
- [ ] `EXT-02` Training protection/lifecycle completion proven.
- [ ] `EXT-03` external repository governance accepts field-scoped `$Default` ownership.
- [ ] `EXT-04` exact Working/Training AMIs and build evidence available.
- [ ] Notification recipients, thresholds and cost owners use real approved values.
- [ ] Named nonproduction account/region/environment and explicit plan authorization recorded.

Until these gates pass, no workflow dispatch, live plan/apply, LT promotion, refresh, scale action or
instance replacement is represented as completed.
