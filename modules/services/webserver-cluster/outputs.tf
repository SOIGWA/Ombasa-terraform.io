output "vpc_id" {
  description = "The ID of the VPC"
  value       = local.vpc_id
}

output "public_subnet_cidrs" {
  description = "Map of public subnet names to their CIDR blocks"
  value       = { for k, v in aws_subnet.public : k => v.cidr_block }
}

output "private_subnet_cidrs" {
  description = "Map of private subnet names to their CIDR blocks"
  value       = { for k, v in aws_subnet.private : k => v.cidr_block }
}

output "alb_dns_name" {
  description = "The domain name of the load balancer"
  value       = aws_lb.main_alb.dns_name
}

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ombasa_asg.name
}

output "instance_name" {
  description = "The base name used for instances"
  value       = "${var.cluster_name}-instance"
}

output "active_environment" {
  description = "The currently active deployment environment (blue or green)"
  value       = var.active_environment
}

output "db_connection_string" {
  description = "The connection endpoint for the RDS instance"
  value       = "mysql://${aws_db_instance.ombasa_db.username}@${aws_db_instance.ombasa_db.endpoint}"
  sensitive   = true
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}
