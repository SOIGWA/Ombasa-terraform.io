locals {
  is_production     = var.environment == "production"
  instance_type     = local.is_production ? "t2.medium" : var.instance_type
  min_size          = local.is_production ? 3 : 1
  max_size          = local.is_production ? 10 : 3
  enable_monitoring = local.is_production

  # vpc_id resolution: explicit var.vpc_id (tests) > existing VPC lookup > newly created VPC
  vpc_id = var.vpc_id != null ? var.vpc_id : (
    var.use_existing_vpc ? data.aws_vpc.existing[0].id : aws_vpc.new[0].id
  )

  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.cluster_name
    Owner       = var.team_name
  }

  db_credentials = var.environment == "dev" ? {
    username = "admin"
    password = "Ombasadev1150!"
    } : jsondecode(
    data.aws_secretsmanager_secret_version.db_credentials[0].secret_string
  )
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
