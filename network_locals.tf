locals {
  network_subnets = {
    public_a = {
      availability_zone = var.availability_zones[0]
      cidr_block        = var.subnet_cidrs.public_a
      tier              = "public"
    }
    public_b = {
      availability_zone = var.availability_zones[1]
      cidr_block        = var.subnet_cidrs.public_b
      tier              = "public"
    }
    private_app_a = {
      availability_zone = var.availability_zones[0]
      cidr_block        = var.subnet_cidrs.private_app_a
      tier              = "private-application"
    }
    private_app_b = {
      availability_zone = var.availability_zones[1]
      cidr_block        = var.subnet_cidrs.private_app_b
      tier              = "private-application"
    }
    private_db_a = {
      availability_zone = var.availability_zones[0]
      cidr_block        = var.subnet_cidrs.private_db_a
      tier              = "private-database"
    }
    private_db_b = {
      availability_zone = var.availability_zones[1]
      cidr_block        = var.subnet_cidrs.private_db_b
      tier              = "private-database"
    }
  }

  public_subnets = {
    for subnet_name, subnet in local.network_subnets :
    subnet_name => subnet if subnet.tier == "public"
  }

  private_application_subnets = {
    for subnet_name, subnet in local.network_subnets :
    subnet_name => subnet if subnet.tier == "private-application"
  }

  private_database_subnets = {
    for subnet_name, subnet in local.network_subnets :
    subnet_name => subnet if subnet.tier == "private-database"
  }
}
