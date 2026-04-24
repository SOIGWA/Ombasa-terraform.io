# modules/services/webserver-cluster/providers.tf
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Changed from ~> 5.0 to a specific stable version
      version = "5.82.0" 
    } 
  }
}

provider "aws" {
  region = var.aws_region
}
