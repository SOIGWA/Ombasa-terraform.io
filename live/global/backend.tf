provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "state_bucket" {
  bucket = "soigwa-terraform-state-bucket"

  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Name      = "Global Terraform State Bucket"
    ManagedBy = "terraform"
  }
}

resource "aws_dynamodb_table" "locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name      = "Global Terraform Lock Table"
    ManagedBy = "terraform"
  }
}