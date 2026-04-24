Mastering Loops and Conditionals in Terraform: Day 10
In today's installment of the 30-Day Terraform Challenge, we are breaking down the logic that turns static scripts into dynamic, enterprise-grade infrastructure. Using our current VPC and ASG architecture as a baseline, let’s explore the "Big Four" of Terraform flow control.

1. The Ternary Operator (Conditionals)
The ternary operator is a one-line if/else statement: condition ? true_val : false_val.

In our code, we use this to decide whether to deploy a remote backend. We only want it enabled if the enable_backend variable is true and we aren't in a test workspace.

From our code:

Terraform
locals {
  create_backend = (var.enable_backend && terraform.workspace != "test") ? 1 : 0
}
2. The count Meta-Argument
count is a simple iterative tool. It defines how many copies of a resource to create based on a whole number.

From our code (S3 Backend):

Terraform
resource "aws_s3_bucket" "state_bucket" {
  count  = local.create_backend
  bucket = "soigwa-terraform-state-${terraform.workspace}"
}
Logic: If create_backend is 1, the bucket is created. If 0, it's skipped.

The "Count Index Problem"
Why didn't we use count for our subnets? If we had a list of subnets ["sub-a", "sub-b", "sub-c"] and used count, Terraform maps them to indices [0, 1, 2].

What breaks: If you delete "sub-a" from the start of your list, "sub-b" shifts to index [0]. Terraform thinks you want to delete the old "sub-b" and rename the resource at index [0]. This leads to unnecessary resource destruction.

3. The for_each Meta-Argument
for_each is the professional way to handle multiple resources. It maps resources to a key (like a name) rather than an index number.

From our code (Subnets):

Terraform
resource "aws_subnet" "public" {
  for_each   = var.public_subnets # A map of subnet names to CIDR offsets
  vpc_id     = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value + 10)
  tags       = merge(local.common_tags, { Name = each.key })
}
Why it fixes the problem: If we remove a subnet from the map, Terraform identifies it by its key (e.g., "public_subnet_1"). Only that specific subnet is deleted; the others remain untouched because their keys didn't change.

4. for Expressions
for expressions transform lists or maps into new formats. We use these inside resource arguments to gather data from other resources.

From our code (ALB & ASG):
We need a list of Subnet IDs for our Load Balancer and Auto Scaling Group, but our subnets were created as a map via for_each. We use a for expression to extract just the IDs.

Terraform
resource "aws_lb" "main_alb" {
  # ...
  subnets = [for s in aws_subnet.public : s.id] 
}

resource "aws_autoscaling_group" "ombasa_asg" {
  # ...
  vpc_zone_identifier = [for s in aws_subnet.private : s.id]
}
