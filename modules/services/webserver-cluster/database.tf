data "aws_secretsmanager_secret" "db_credentials" {
  count = var.environment == "dev" ? 0 : 1
  name  = "prod/db/credentials-v2"
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.environment == "dev" ? 0 : 1
  secret_id = data.aws_secretsmanager_secret.db_credentials[0].id
}

resource "aws_db_subnet_group" "db_subnets" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = local.common_tags
}

resource "aws_db_instance" "ombasa_db" {
  identifier             = "${var.cluster_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "ombasadb"
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  multi_az               = local.is_production
  username               = local.db_credentials["username"]
  password               = local.db_credentials["password"]
  allocated_storage      = 20 # RDS minimum is 20 GiB
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  lifecycle {
    prevent_destroy = false
  }
}
