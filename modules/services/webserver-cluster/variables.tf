variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "ombasa_vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Map of public subnet names to their index for CIDR calculation"
  type        = map(number)
  default = {
    "public_subnet_1" = 1
    "public_subnet_2" = 2
    "public_subnet_3" = 3
  }
}

variable "private_subnets" {
  description = "Map of private subnet names to their index for CIDR calculation"
  type        = map(number)
  default = {
    "private_subnet_1" = 1
    "private_subnet_2" = 2
    "private_subnet_3" = 3
  }
}

variable "enable_backend" {
  description = "Set to true to create S3 and DynamoDB for state"
  type        = bool
  default     = true
}

variable "use_existing_vpc" {
  type    = bool
  default = false
}

variable "cluster_name" {
  description = "The name to use for all cluster resources"
  type        = string
  default     = "ombasa-cluster"
}

variable "team_name" {
  description = "The name of the team that owns these resources"
  type        = string
  default     = "cloud-engineering"
}

variable "environment" {
  description = "Deployment environment: dev, staging, or production"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the cluster"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be a t2 or t3 family type."
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Port number for the database connection"
  type        = number
  default     = 3306
}

variable "active_environment" {
  description = "Which environment is currently active: blue or green"
  type        = string
  default     = "blue"
}

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "The ID of the VPC to deploy into (used for E2E tests)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "The list of subnet IDs to deploy into (used for E2E tests)"
  type        = list(string)
  default     = []
}
