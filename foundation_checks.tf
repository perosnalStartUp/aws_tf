check "name_prefix_length" {
  assert {
    condition     = length(local.name_prefix) <= 42
    error_message = "The normalized project-environment name prefix must not exceed 42 characters."
  }
}

check "subnet_cidrs_within_vpc" {
  assert {
    condition = alltrue([
      for subnet_range in local.subnet_range_list :
      subnet_range.start >= local.vpc_network_start &&
      subnet_range.end <= local.vpc_network_end
    ])
    error_message = "Every subnet CIDR must be fully contained within vpc_cidr."
  }
}

check "subnet_cidrs_do_not_overlap" {
  assert {
    condition = alltrue([
      for pair in local.subnet_cidr_pairs :
      pair.left.end < pair.right.start ||
      pair.right.end < pair.left.start
    ])
    error_message = "Subnet CIDRs must not overlap."
  }
}

check "backend_capacity_bounds" {
  assert {
    condition = (
      var.backend_capacity.min >= 0 &&
      var.backend_capacity.min <= var.backend_capacity.desired &&
      var.backend_capacity.desired <= var.backend_capacity.max &&
      var.backend_capacity.desired == 1
    )
    error_message = "Backend capacity must satisfy 0 <= min <= desired <= max and initial desired must equal 1."
  }
}

check "training_capacity_bounds" {
  assert {
    condition = (
      var.training_capacity.min == 0 &&
      var.training_capacity.desired == 0 &&
      var.training_capacity.max >= 1
    )
    error_message = "Training initial capacity must use min=0, desired=0, and max>=1."
  }
}
