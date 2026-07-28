locals {
  name_prefix = "${var.project_name}-${var.environment}"

  component_names = {
    backend  = "${local.name_prefix}-backend"
    working  = "${local.name_prefix}-working"
    training = "${local.name_prefix}-training"
  }

  required_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = trimspace(var.owner)
    CostCenter  = trimspace(var.cost_center)
    ManagedBy   = "Terraform"
  }

  common_tags = merge(var.extra_tags, local.required_tags)

  vpc_network_start = sum([
    for octet_index, octet in split(".", cidrhost(var.vpc_cidr, 0)) :
    tonumber(octet) * pow(256, 3 - octet_index)
  ])
  vpc_network_end = local.vpc_network_start + pow(2, 32 - tonumber(split("/", var.vpc_cidr)[1])) - 1

  subnet_ranges = {
    for subnet_name, subnet_cidr in var.subnet_cidrs : subnet_name => {
      start = sum([
        for octet_index, octet in split(".", cidrhost(subnet_cidr, 0)) :
        tonumber(octet) * pow(256, 3 - octet_index)
      ])
      end = sum([
        for octet_index, octet in split(".", cidrhost(subnet_cidr, 0)) :
        tonumber(octet) * pow(256, 3 - octet_index)
      ]) + pow(2, 32 - tonumber(split("/", subnet_cidr)[1])) - 1
    }
  }

  subnet_range_list = values(local.subnet_ranges)
  subnet_cidr_pairs = flatten([
    for left_index, left_range in local.subnet_range_list : [
      for right_index, right_range in local.subnet_range_list : {
        left  = left_range
        right = right_range
      } if left_index < right_index
    ]
  ])
}
