What the module does
This module automates the deployment of a highly available web server cluster on AWS. It packages together an Auto Scaling Group (ASG) to manage EC2 instances across multiple availability zones and an Application Load Balancer (ALB) to distribute incoming HTTP traffic. By using this module, you move away from manual "monolithic" scripts and instead use a reusable blueprint that ensures your web servers are secure, scalable, and easy to manage through standardized tags.

Input Variables
cluster_name

Type: string

Description: The name used to identify all resources in this cluster (e.g., "webservers-dev").

Default: n/a (This is a required input).

server_port

Type: number

Description: The port the EC2 instances will listen on for HTTP requests.

Default: 8080

instance_type

Type: string

Description: The type of EC2 instance to run.

Default: "t2.micro"

min_size

Type: number

Description: The minimum number of EC2 instances the ASG should keep running.

Default: 2

max_size

Type: number

Description: The maximum number of EC2 instances the ASG can scale up to.

Default: 5

environment

Type: string

Description: Added in v0.0.2 to help with resource tagging (e.g., "staging" or "production").

Default: "dev"

Outputs
alb_dns_name: The public URL of the Load Balancer. This is what you actually paste into your browser to see your website.

asg_name: The name of the Auto Scaling Group, useful if you need to reference it for specialized scaling policies later.

Usage Example (Minimum Inputs)
To use this module in your live environment, your code should look like this:

module "webserver_cluster" {
source       = "github.com/SOIGWA/Ombasa-terraform.io?ref=v0.0.2"
cluster_name = "ombasa-web-stage"
}

Known Limitations & Gotchas
Port Conflicts: If your User Data script inside the module runs a service on port 80 but your server_port variable is set to 8080, the health checks will fail and the ALB will mark the instances as unhealthy.

Hardcoded AMIs: Depending on your setup, the Amazon Machine Image (AMI) ID might be specific to the us-east-1 region. If you try to deploy this in a different region, the deployment will fail because the AMI won't be found.

Large File Push: Avoid running "git add ." without a proper .gitignore, as the .terraform folder contains large provider binaries that exceed GitHub's 100MB limit.

Tag Dependency: Since v0.0.2, the module expects an "environment" tag. If you are migrating from v0.0.1, ensure your resource blocks in main.tf are updated to accept the var.environment variable.