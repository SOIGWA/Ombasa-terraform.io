variables {
  cluster_name  = "ombasa-cluster"
  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 10
  environment   = "dev"
}

run "validate_cluster_name" {
  command = plan

  assert {
    condition     = aws_launch_template.ombasa_lt.name_prefix == "${var.cluster_name}-lt-"
    error_message = "ASG name must contain the cluster_name variable"
  }
}

run "validate_instance_type" {
  command = plan

  assert {
    condition     = aws_launch_template.ombasa_lt.instance_type == var.instance_type
    error_message = "Launch template instance type must match the instance_type variable"
  }
}

run "validate_security_group_port" {
  command = plan

  assert {
    condition = anytrue([
      for ingress in aws_security_group.app_sg.ingress : ingress.from_port == 80
    ])
    error_message = "Security group must allow traffic on port 80"
  }
}