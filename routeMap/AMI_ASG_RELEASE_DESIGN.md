# AMI, Launch Template, and ASG Release Design

Status: confirmed target ownership model; implementation not started.

## 1. Why the Ownership Is Split

Terraform creates and reviews infrastructure structure. A routine application release should be
able to move an immutable AMI without granting the workflow authority to redesign the instance.
Therefore both systems touch a Launch Template, but they must not own the same fields:

| Surface | Terraform | Release workflow |
| --- | --- | --- |
| LT existence, name, tags | Owns | Read only |
| instance type, SGs, IAM profile, metadata, storage, user data | Owns | Must not change |
| initial approved AMI | Bootstraps | N/A |
| routine AMI-only LT version | Must not reset | Creates |
| LT `$Default` pointer | Must not promote/reset during normal apply | Promotes/restores |
| ASG capacity, subnet, health, scaling | Owns | Read only |
| Backend Instance Refresh | Configures policy boundary | Starts/observes |
| Training forced replacement | Not automatic | Prohibited for normal AMI release |

This is safe only if the field boundary is enforced in Terraform lifecycle, workflow verification,
IAM, and operational checks.

## 2. Terraform Configuration Contract

For Backend and Training:

- the Launch Template is Terraform-managed;
- `update_default_version` remains false;
- the ASG consumes version `$Default`;
- Terraform ignores only the routine AMI drift owned by release automation;
- Terraform does not ignore instance profile, user data, security groups, instance type, metadata,
  disks, tags, or other structural settings;
- exact syntax must be validated against the pinned AWS provider before implementation.

A Terraform structural LT edit normally creates a new `$Latest` candidate. It must not silently
promote that candidate. An operator/reviewed workflow explicitly promotes the intended version
after confirming its full structural diff.

Before creating a structural candidate, synchronize the exact AMI input recorded in Terraform with
the currently approved `$Default` AMI. Otherwise Terraform can create a structurally updated
candidate that carries the stale bootstrap AMI from configuration; promoting that version later
would unintentionally roll the service backward. The plan/review must compare the candidate AMI
against the captured `$Default` AMI before promotion.

## 3. Packer Handoff

Each component build must produce:

- exact AMI ID and region/account;
- source commit and build/run identity;
- component/environment compatibility metadata;
- immutable container digest where containers are used;
- test/scan results actually run;
- machine-readable Packer manifest or equivalent signed/trusted output.

The release consumes the exact AMI ID from that run. Name/tag searches may be used for diagnostics,
not as production selection authority.

Repository ownership:

- Backend Packer output originates in `small_backend`.
- Working and Training Packer output originates in `gpu_ec2`.
- Backend release is executed from `small_backend`.
- Training release is executed from `gpu_ec2`.
- Working V0 deployment is executed through the `terraform` repository after its approved Packer
  manifest is converted into an explicit Terraform AMI input change.

Artifact handoff does not grant the build workflow permission to mutate Terraform State, Launch
Templates, ASGs, or live instances.

## 4. Routine Backend Release

1. Acquire component/environment concurrency lock.
2. Assume the Backend release role through GitHub OIDC.
3. Read the current LT `$Default` version and capture its version and AMI ID.
4. Validate the new exact AMI ID, region, account ownership, state, architecture, and component
   tags.
5. Create a new LT version using `$Default` as source and changing only `ImageId`.
6. Retrieve both LT version payloads, normalize service-generated fields, and fail unless the only
   allowed semantic difference is `ImageId`.
7. Promote the candidate to `$Default`.
8. Verify `$Default` points to the candidate and the ASG still references `$Default`.
9. Start Backend Instance Refresh with reviewed health/warmup/min-healthy/rollback settings.
10. Observe refresh, ALB target health, application health, and actual instance AMI/LT versions.
11. Record release evidence.

On failure, restore the previous `$Default`. If instances have already changed, use a reviewed
rollback refresh or other explicit fleet operation. Restoring the pointer alone affects future
launches; it does not revert existing instances.

## 5. Routine Training Release

Steps 1–8 match Backend with the Training-specific role, LT, and AMI validation.

After promotion:

- do not start a normal Instance Refresh;
- do not remove scale-in protection from active jobs;
- do not terminate active workers merely to reach version uniformity;
- verify new scale-outs use the new `$Default`;
- allow protected workers to finish and terminate through the designed lifecycle path;
- record a mixed-version fleet as expected during draining, not as an automatic failure.

A deliberate drain/replace operation is separate from routine release and requires explicit user
authorization plus lifecycle evidence.

## 6. Working V0 Exception

Working V0 has no Launch Template or ASG. Its exact AMI ID is a Terraform input. Updating it causes
a reviewed Terraform replacement and Route53 private-record update. A GitHub workflow may invoke
the Terraform plan/apply process after approval, but it must not call LT/ASG APIs for Working V0.

## 7. Rollback Rules

- Capture previous default version/AMI before mutation.
- Treat LT version creation as immutable; rollback changes pointers/instances rather than editing a
  version.
- Restore `$Default` when validation or rollout fails.
- Verify both control plane and data plane:
  - LT default/latest version;
  - ASG referenced version;
  - instance ID, AMI ID, LT version, lifecycle state;
  - ALB/application health for Backend;
  - job protection/completion state for Training.
- Do not delete the failed version or AMI automatically; retention/deletion is a separate approved
  operation.

## 8. Workflow IAM Boundary

Each component release role is scoped to its approved repository/ref/environment and resources.
It may need only the relevant read/describe calls plus:

- create LT version for the one component LT;
- modify that LT's default version;
- start/describe/cancel Backend Instance Refresh for the Backend ASG, where required;
- read instances/tags/images for verification.

The Training release role does not receive refresh or instance-termination authority for a routine
release. Neither release role may alter IAM, security groups, ASG capacity, user data, disks,
networking, metadata options, or other LT structure.

Some AWS `Describe*` calls require `Resource = "*"`. Document these unavoidable exceptions
individually and constrain mutation actions precisely.

## 9. Concurrency and Failure Cases

Serialize by account/region/environment/component. Otherwise two workflows can:

- clone the same old default;
- race to promote different versions;
- restore the wrong version during failure handling;
- overlap Backend refreshes;
- make release evidence ambiguous.

The workflow must fail closed if:

- `$Default` changes between capture and promotion;
- source/candidate normalized diff contains a non-AMI field;
- the AMI is not available or belongs to the wrong account/region/component;
- the ASG no longer references `$Default`;
- a rollout is already in progress;
- health or instance-version verification is inconclusive.

## 10. Terraform Drift Behavior

Expected routine release state:

- AWS `$Default` and `ImageId` differ from the original Terraform bootstrap value;
- Terraform plan must not reset those workflow-owned values;
- all other structural drift remains visible.

Before changing lifecycle semantics, test these three cases in a nonproduction plan:

1. no external release: plan is stable;
2. AMI-only workflow release: plan does not roll back the AMI/default pointer;
3. structural drift: plan detects and proposes correction.

Also test a structural LT update after at least one workflow AMI release. The new structural
candidate must preserve the currently approved default AMI rather than reintroducing the initial
bootstrap AMI.

## 11. Cross-Repository Governance Blocker

The GPU repository currently states that Terraform is the sole Launch Template/ASG writer and that
release workflows pass AMI IDs back to Terraform. That wording conflicts with the confirmed model
above. Synchronize the GPU governance/design documents before implementing or enabling the release
workflow. Until then, this file records the owner's intended direction, not an active production
contract.

The workflow repository locations are confirmed, but the field-ownership wording conflict remains
an implementation gate for Backend/Training release roles and workflows.
