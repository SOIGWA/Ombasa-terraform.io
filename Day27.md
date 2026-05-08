Building a 3-Tier Multi-Region High Availability Architecture with Terraform
In this post, we’ll explore how to build a robust, production-grade infrastructure on AWS that can survive the complete failure of an entire AWS region.

The Architecture Overview
This project implements a classic 3-tier web application (Web, Application, and Database) across two geographically distinct regions: us-east-1 (Primary) and us-west-2 (Secondary).

Why Five Separate Modules?
Instead of writing one massive configuration file, we divided the infrastructure into five distinct modules: VPC, ALB, ASG, RDS, and Route53.

Separation of Concerns: Each module has a single responsibility; networking is isolated from database logic.

Reusability: By parameterizing these modules, we can call them twice—once for the primary region and once for the secondary—without duplicating code.

Maintainability: Fixing a bug in the security group logic only requires changing code in one place (e.g., the ASG module) to update both regions.

Connecting the Dots: Data Flow Between Modules
The power of this modular setup lies in how Terraform passes data from one module to another using outputs and variables.

From Load Balancer to Auto Scaling Group
The Auto Scaling Group needs to know where to send its traffic. We achieve this by taking the target_group_arn produced by the ALB module and passing it into the ASG module:

Terraform
module "asg_primary" {
  source                = "../../modules/asg"
  target_group_arns     = [module.alb_primary.target_group_arn] # Data flows here
  alb_security_group_id = module.alb_primary.alb_security_group_id
  # ...
}
From Primary Database to Read Replica
For cross-region disaster recovery, the secondary database must be a clone of the primary. We capture the db_instance_arn from the primary region and inject it into the secondary module as the source for replication:

Terraform
module "rds_replica" {
  source              = "../../modules/rds"
  replicate_source_db = module.rds_primary.db_instance_arn # Data flows here
  is_replica          = true
  # ...
}
Disaster Recovery: Failover in Action
We use Route53 Failover Routing to manage global traffic.

The Route53 Console
In a healthy state, the Route53 console shows both regional health checks as Green (Healthy). Route53 directs 100% of traffic to the Primary region because its routing policy is set to PRIMARY.

Tracing a Regional Failover
What happens if us-east-1 goes offline?

Health Check Failure: The Route53 Health Check (probing /health on the Primary ALB) detects consecutive failures.

DNS TTL Expiry: Once the DNS record's Time-to-Live (TTL) expires, recursive DNS servers check with Route53 for a fresh record.

Traffic Shifting: Route53 sees the Primary is "Unhealthy" and automatically begins responding to DNS queries with the IP address of the SECONDARY ALB in us-west-2.

Multi-AZ vs. Cross-Region: Knowing the Difference
It is vital to understand that these two features protect against different types of disasters:

Multi-AZ (Intra-Region): This protects against the failure of a single data center (Availability Zone). If the primary database fails, RDS automatically fails over to a standby in another AZ within the same region. It provides high availability but doesn't help if the whole region goes dark.

Cross-Region Read Replicas: This is your "Insurance Policy" against a total regional outage. Data is asynchronously replicated thousands of miles away to a different region. If the entire Primary region fails, you can promote the replica to be your new standalone primary database.

By combining both, we ensure that our application is resilient at every level of the AWS global infrastructure.
