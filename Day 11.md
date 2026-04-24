---
layout: default
title: "Deploying Your First Server with Terraform"
---
# Deploying Your First Server with Terraform: A Beginner’s Guide

Hello\! Welcome to my blog. As part of my journey in learning cloud infrastructure, I recently took on the challenge of deploying a real web server using Terraform.

If you are new to Infrastructure as Code (IaC), the idea of writing code to create actual servers, networks, and storage might sound complex. But it’s surprisingly logical once you break it down.

In this guide, I’m going to walk you through exactly how I deployed my first web server on AWS using Terraform. I’ll share the actual code I used, explain the core commands, and, most importantly, talk about **what broke and how I fixed it**. (Because let’s face it, that’s what we all actually search for\!)

-----

## What We are Building

We aren't just launching a lone server. To do this properly, we need to create the networking "house" for it to live in. Our deployment includes:

1.  **A Virtual Private Cloud (VPC):** A private network isolated just for our resources.
2.  **A Public Subnet:** A segment of the network that has access to the internet.
3.  **An Internet Gateway (IGW):** The door connecting our VPC to the public internet.
4.  **A NAT Gateway & Elastic IP:** Allows resources in private networks (which we can add later) to reach the internet securely.
5.  **A Security Group:** A firewall that only allows specific traffic (like HTTP and SSH) into our server.
6.  **An EC2 Instance:** The actual virtual server that will run our "web server."
7.  **An S3 Bucket:** A simple storage container.

Here is what the architecture looks like:

*(Tip: In diagrams, place your NAT Gateway in the Public Subnet so it can reach the Internet Gateway\!)*

-----

## The Code: Breaking It Down Step-by-Step

Let's look at the actual Terraform configuration file (`main.tf`). I’ve broken it into logical blocks.

### Step 1: Telling Terraform Where to Build

We start by defining the *provider*. This tells Terraform which cloud we are using (AWS) and which region to build in.

```hcl
# The Provider block defines which cloud and region we are targeting.
provider "aws" {
  region = "eu-central-1" # I chose Frankfurt. Pick the region closest to you!
}
```

### Step 2: Creating the Network Foundation

Next, we build the environment where our server will live. This is the networking stack.

```hcl
# 1. Create the VPC (The virtual network "house")
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16" # This defines the range of IP addresses for the whole VPC.
  tags = {
    Name = "demo_vpc"
  }
}

# 2. Create the Public Subnet (A room within the house)
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.demo_vpc.id # Attach this subnet to the VPC we just created.
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true # This ensures our server gets a public IP address!

  tags = {
    Name = "public_subnet"
  }
}

# 3. Create the Internet Gateway (The front door)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "demo_igw"
  }
}

# 4. We also created a NAT Gateway. This needs a static IP (Elastic IP).
resource "aws_eip" "nat_eip" {
  vpc = true # This IP is for use within a VPC context.
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id # Tie the static IP to the NAT Gateway.
  subnet_id     = aws_subnet.public_subnet.id # CRITICAL: The NAT Gateway MUST live in the Public Subnet.

  tags = {
    Name = "demo_nat_gw"
  }
}
```

### Step 3: Setting Up the Firewall (Security Group)

Before we launch the server, we need to tell AWS who is allowed to talk to it. A Security Group acts like a firewall at the server level.

```hcl
# Create the Security Group to allow web traffic
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound HTTP and SSH traffic"
  vpc_id      = aws_vpc.demo_vpc.id

  # Inbound rule for HTTP (Web Server)
  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # '0.0.0.0/0' means 'the entire internet'
  }

  # Inbound rule for SSH (Remote Management)
  ingress {
    description      = "SSH from anywhere" # Ideally, change this to your specific IP!
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Outbound rules (All traffic out is allowed)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # '-1' means all protocols
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
```

### Step 4: Launching the Server (EC2) and Storage (S3)

Finally, we create the actual compute instance and our storage bucket.

```hcl
# 1. Launch the EC2 Instance (Our Web Server)
resource "aws_instance" "terraform_web_server" {
  ami           = "ami-04e601abe3e1a910f" # Ubuntu 22.04 LTS AMI for eu-central-1. (Find this in the AWS Console!)
  instance_type = "t2.micro" # The 'Free Tier' eligible instance type.
  subnet_id     = aws_subnet.public_subnet.id # Put it in our Public Subnet.
  
  # Attach the security group we created above.
  vpc_security_group_ids = [aws_security_group.allow_web_traffic.id]

  # This 'user_data' script runs ONCE when the server first boots up.
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "<h1>Deployed via Terraform!</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "Terraform-Web-Server"
  }
}

# 2. Create an S3 Bucket (Simple storage)
resource "aws_s3_bucket" "my_test_bucket" {
  bucket = "my-new-tf-test-bucket-ombasa" # S3 bucket names MUST be globally unique! Change this!
  
  tags = {
    Name        = "MyTestBucket"
    Environment = "Dev"
  }
}
```

-----

## The Workflow: Init, Plan, Apply

With the code written, it’s time to use the three core Terraform commands. This is the heart of the "Terraform Workflow."

### 1\. `terraform init` (The Setup)

Think of this as "installing the plugins." When you run this command, Terraform reads your `main.tf` file, sees you are using the `aws` provider, and downloads the necessary code (the provider binary) so it knows how to talk to AWS's API.

  * *Output:* Look for "Terraform has been successfully initialized\!"

### 2\. `terraform plan` (The Preview)

This is your safety net. It creates an execution plan. Terraform compares the code you wrote (`main.tf`) against what *actually exists* in AWS right now. It then prints out exactly what it will do: which resources it will `+ create`, `~ update`, or `- destroy`.

  * *Output:* Read this carefully\! Make sure it shows `Plan: 7 to add, 0 to change, 0 to destroy` (or whatever number matches your resources).

### 3\. `terraform apply` (The Execution)

This is the moment of truth. When you run this, Terraform performs the actions from the `plan` phase. It makes the API calls to AWS to create your network, security groups, EC2 instance, and S3 bucket.

  * *Note:* You will have to type `yes` to confirm the action.

-----

## What Broke and How I Fixed It

This part is for my fellow searchers\! My deployment didn't go perfectly on the first try. Here are the two main issues I ran into:

### Issue \#1: The "Non-Unique S3 Bucket Name" Error

My first `terraform apply` failed with a huge error message related to the S3 bucket.

  * **What the error said:** `Error: Creating S3 Bucket: BucketAlreadyExists: The requested bucket name is not available.`
  * **What it meant:** I tried to create a bucket named `my-test-bucket`. **S3 bucket names must be globally unique across all of AWS.** Someone else, somewhere in the world, had already claimed that name.
  * **The Fix:** I had to change the `bucket` parameter in my `aws_s3_bucket` block to something unique. I added my username: `my-new-tf-test-bucket-ombasa`. After that, the `terraform plan` worked perfectly.

### Issue \#2: A Connection Timeout When Testing the Website

After the `terraform apply` finished successfully, I copied the public IP address of my new EC2 instance and pasted it into my web browser. I expected to see "Deployed via Terraform\!" but instead, the page just kept loading and eventually timed out.

  * **What it meant:** The server was running, and Apache was installed (I verified this later), but something was blocking the traffic between my browser and the server.
  * **Where I looked:** The Security Group.
  * **The Fix:** I realized I had defined the *ingress* rules (traffic coming in) for SSH (Port 22) but I had completely forgotten to add the rule for **HTTP (Port 80)**\! I went back into `main.tf`, added the Port 80 ingress block (which you see in the code above), ran `terraform apply` again, and—voila\!—the page loaded instantly.

-----

## Conclusion

By following these steps, you’ve not just deployed a server; you’ve created a whole network architecture—all from a single code file. This is the power of Infrastructure as Code.

If you are following along, don't be discouraged by errors. They are just Terraform telling you *why* your deployment didn't work. Read the error messages, check your Security Groups, make sure your S3 names are unique, and you will get there\!

Thanks for reading. Happy scripting\!
