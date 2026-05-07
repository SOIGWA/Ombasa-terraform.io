---
layout: post
title: "Building a Scalable Web Application on AWS with EC2, ALB, and Auto Scaling using Terraform"
date: 2024-05-22
categories: [Cloud Computing, Terraform, AWS]
---

Modern cloud architecture isn't just about getting an application online; it’s about ensuring it can handle traffic spikes without manual intervention. In this project, we deploy a highly available web application infrastructure using **Terraform** to orchestrate AWS services.

## Project Structure: Why Modularize?

Instead of a single monolithic `main.tf`, this project is split into three distinct modules: **Networking/ALB**, **Compute (EC2)**, and **Auto Scaling (ASG)**.

* **Reusability:** The ALB module can be reused for different microservices without dragging along specific ASG logic.
* **Blast Radius Reduction:** Changing a Launch Template configuration in the Compute module won't accidentally trigger a recreation of the Load Balancer.
* **Maintainability:** It separates concerns. Networking logic stays in the VPC/ALB domain, while scaling logic stays in the ASG domain.

### Data Flow: Closing the Loop

One of the biggest challenges in Infrastructure as Code (IaC) is managing dependencies between modules. Here is how our data flows to create a cohesive system:

1.  **Launch Template to ASG:** The `ec2` module defines the blueprint of our server (AMI, Instance Type, Security Groups). The `module.ec2.launch_template_id` is passed as an input to the `asg` module, telling the Auto Scaling Group exactly what kind of instance to spin up.
2.  **ALB to ASG:** The `alb` module creates the entry point. The `module.alb.target_group_arn` is passed to the `asg` module. This "closes the loop," ensuring that any instance the ASG creates is automatically registered with the Load Balancer to start receiving traffic.

## Technical Deep Dive

### Health Check Type: EC2 vs. ELB

In the ASG module, we set `health_check_type = "ELB"`. 

By default, an ASG only checks if the EC2 instance is "running" (status checks). However, an instance can be "running" while the web server (Nginx/Apache) inside it has crashed or the application is returning 500 errors. 

By setting it to **ELB**, the ASG listens to the Load Balancer's target group health checks. If the ALB finds that a target is failing its HTTP health check, the ASG marks that instance as unhealthy and replaces it immediately. This is critical for **auto scaling correctness**.

### Scaling Under Pressure: The 70% CPU Path

What happens when your app goes viral? We’ve configured a CloudWatch alarm to monitor the average CPU utilization across the group.

1.  **Detection:** CloudWatch monitors the `CPUUtilization` metric. Once it exceeds **70%** for a sustained period, the alarm moves to the `ALARM` state.
2.  **Trigger:** The alarm triggers the **ASG Scaling Policy**.
3.  **Action:** The policy instructs the Auto Scaling Group to increase the "Desired Capacity" (e.g., from 2 to 4).
4.  **Provisioning:** The ASG uses the `launch_template_id` to request new EC2 instances.
5.  **Integration:** As soon as the instances are up, they are attached to the `target_group_arn`. The ALB begins routing traffic to them once they pass health checks.

## Results & Verification

### ALB DNS Output
Once the `terraform apply` is complete, the ALB provides a DNS name. This is the single entry point for your users:

```bash
Outputs:
alb_dns_name = "web-app-alb-123456789.us-east-1.elb.amazonaws.com"
