data "aws_ami" "ubuntu_22_04" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_launch_template" "ombasa_lt" {
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = data.aws_ami.ubuntu_22_04.id
  instance_type = local.instance_type

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = aws_db_instance.ombasa_db.address
    db_port     = var.db_port
  }))

  network_interfaces {
    security_groups             = [aws_security_group.app_sg.id]
    associate_public_ip_address = false
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.cluster_name}-instance"
    })
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "ombasa_asg" {
  name_prefix         = "${var.cluster_name}-asg-"
  vpc_zone_identifier = local.asg_subnet_ids

  target_group_arns = [
    var.active_environment == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  ]

  health_check_type = "ELB"
  min_size          = local.min_size
  max_size          = local.max_size

  launch_template {
    id      = aws_launch_template.ombasa_lt.id
    version = "$Latest"
  }

  # Wait for NAT gateway to be fully ready before launching instances.
  # Without this, instances boot in private subnets before outbound internet
  # is available, so user-data.sh can't install python3 and the web server
  # never starts — causing ALB health checks to fail for the entire test window.
  depends_on = [aws_nat_gateway.main_nat]

  lifecycle { create_before_destroy = true }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = var.cluster_name })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
