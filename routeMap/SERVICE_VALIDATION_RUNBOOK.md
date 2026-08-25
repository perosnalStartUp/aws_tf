# Backend Review and Working Replacement Runbook

## Status

This document supplies the local/static PR28 procedures for `BE-010` and `WK-006`. It does not
contain live plan, apply, replacement, DNS, or health evidence. Those actions begin only in PR29/30
after a named nonproduction environment and explicit authorization exist.

## Backend Plan Review

Review the saved, authorized nonproduction plan against all items below.

### Exposure and routing

- The only internet-facing resource is `aws_lb.backend`.
- Port `80` has only a redirect action to HTTPS `443`; it has no forwarding action.
- Port `443` uses the approved ACM certificate and TLS policy and forwards only to
  `aws_lb_target_group.backend`.
- Backend instances are in both private application subnets, have no public IP, and are reachable
  on the application port only from the Backend ALB security group.
- Working, Training and RDS remain private. There is no inbound SSH rule.
- Training's public Backend callback uses the single NAT path and application authentication; it is
  not represented as a security-group identity path.

### Backend capacity, data and lifecycle

- `aws_autoscaling_group.backend.desired_capacity` is exactly `1`; reviewed min/max bounds remain
  intact.
- The ASG references LT version `$Default`; Terraform does not automatically start an Instance
  Refresh.
- `aws_launch_template.backend` ignores only the release-owned `image_id`. Instance type, user
  data, profile, SGs, disks, metadata and tags remain Terraform-owned and visible in the plan.
- No structural LT change unintentionally carries the stale bootstrap AMI into a candidate that a
  release workflow could promote.
- The target group health path, matcher, thresholds, grace period and deregistration delay match
  the real Backend service.
- Backend-to-RDS ingress is only the database port and only from the Backend SG.
- Runtime IAM obtains the RDS-managed secret and directly references Terraform-created resource
  ARNs; secret values do not appear in user data, plan output, logs or outputs.
- Database migration is absent from ASG startup and remains gated by
  `BACKEND_MIGRATION_RUNBOOK.md`.

### Backend outputs and change classification

- DNS output is the expected public name.
- LT/ASG/target group/ALB outputs identify resources created by this root.
- Release preferences are data for a future release workflow; the Terraform plan does not claim a
  rollout.
- Every create, update, replacement and destroy has an owner and rollback path.
- A no-op plan, AMI-only external release plan, and structural-drift plan are classified separately;
  no live drift result is inferred from Mock tests.

## Working AMI Replacement

Working V0 is exactly one private `aws_instance`. It has no Launch Template, Auto Scaling Group,
target group or ALB. Updating `working_ami_id` is a Terraform replacement with expected service
downtime.

### Preconditions

1. Record the current instance ID, exact AMI ID, private IP/DNS record, volume behavior, health
   result and rollback AMI.
2. Verify the candidate AMI belongs to the approved account/region, is `available`, has the expected
   architecture/root device, includes the reviewed systemd unit, and has immutable build evidence.
3. Verify durable adapters/manifests are in the Terraform-managed product S3 boundary; do not rely
   on the current instance's cache volume.
4. Confirm the Backend can tolerate the approved DNS TTL plus instance boot/model-load time.
5. Confirm no operator session or required request is using the instance.

### Plan and apply boundary

1. Change only the approved environment's `working_ami_id`.
2. Produce a saved nonproduction plan with the real backend/account/region and reviewed variables.
3. Require the plan to show one Working instance replacement and the dependent private Route53
   record update, with no LT/ASG API operation.
4. Review IAM, SG, IMDSv2, encrypted volumes, no-public-IP, tags and user data on the replacement.
5. Apply the exact reviewed saved plan only after separate authorization.

Terraform may destroy before creating because this design has one fixed private DNS record and no
blue/green target. The approved window must therefore assume downtime; the runbook does not promise
zero downtime.

### Verification and rollback

After replacement, record the new instance ID/AMI/private IP, SSM registration, systemd status,
model/adapter load, disk headroom, private health response, Backend-to-Working request, negative
public/SSH reachability, DNS answer/TTL and timestamps.

Rollback changes `working_ami_id` back to the previously recorded exact AMI and follows the same
plan/review/apply/verification process. It is another replacement, not an in-place pointer change.
If the prior AMI or its snapshots are unavailable, rollback is blocked and must not be improvised.

## Evidence Template

| Field | Required value |
| --- | --- |
| Account / region / environment | real named nonproduction values |
| Change approval / operator | ticket and identity |
| Saved plan digest/location | protected artifact reference |
| Previous/new/rollback AMI | exact IDs and immutable build references |
| Previous/new instance | exact IDs |
| DNS before/after | name, answer, TTL and observation times |
| Health | systemd, local/private endpoint and Backend request |
| Security negatives | no public IP, SSH denied, unapproved SG/IAM path denied |
| Downtime | measured start/end; never estimated as evidence |
| Rollback result | not run, passed, failed or blocked with reason |
