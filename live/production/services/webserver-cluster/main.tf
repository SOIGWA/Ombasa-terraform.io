provider "aws" {
  region = "us-west-2"
}
module "webserver_cluster" {
  source = "github.com/SOIGWA/Ombasa-terraform.io//modules/services/webserver-cluster?ref=main"

  cluster_name       = "ombasa-cluster-prod"
  environment        = "production"
  instance_type      = "t3.micro"
  enable_backend     = true
  active_environment = "blue"
}