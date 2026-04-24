# Keep your assume_role if your staging environment lives in a separate AWS account
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/TerraformDeployRole"
  }
}

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  # Staging-specific variables (mimics production but smaller)
  cluster_name       = "ombasa-cluster-staging"
  environment        = "staging"
  instance_type      = "t2.micro"
  enable_backend     = true
  active_environment = "green"
}