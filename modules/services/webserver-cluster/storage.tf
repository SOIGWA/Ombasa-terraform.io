resource "aws_s3_bucket" "app_assets" {
  bucket = "${var.cluster_name}-assets" 
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}