---
layout: post
title: "Deploying Multi-Cloud Infrastructure with Terraform Modules"
date: 2024-01-15
categories: [terraform, devops, kubernetes]
tags: [terraform, aws, kubernetes, docker, infrastructure-as-code]
author: Andy Ombasa
---

# Deploying Multi-Cloud Infrastructure with Terraform Modules

Managing infrastructure across multiple cloud providers or regions can be complex. Terraform's provider alias pattern and module composition give you the flexibility to deploy resources anywhere while keeping your code DRY and maintainable. In this post, we'll explore how to use provider aliases with modules, from a simple Docker example to a production-grade EKS deployment.

## Table of Contents

- [Understanding Provider Aliases](#understanding-provider-aliases)
- [The configuration_aliases Declaration](#the-configuration_aliases-declaration)
- [Quick Start: Docker Provider Example](#quick-start-docker-provider-example)
- [Advanced: EKS + Kubernetes Multi-Provider Setup](#advanced-eks--kubernetes-multi-provider-setup)
- [Best Practices](#best-practices)
- [Conclusion](#conclusion)

---

## Understanding Provider Aliases

By default, Terraform uses a single "default" configuration for each provider. But what if you need to:

- Deploy to multiple AWS regions simultaneously
- Manage resources across different cloud accounts
- Configure Kubernetes resources immediately after cluster creation
- Use different credentials for different environments

**Provider aliases** solve this problem by letting you define multiple configurations for the same provider type.

### Basic Syntax

```hcl
provider "aws" {
  region = "us-east-1"
  # This is the default provider
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

provider "aws" {
  alias   = "prod"
  region  = "eu-central-1"
  profile = "production"
}
```

Now you can reference these providers explicitly:

```hcl
resource "aws_instance" "east" {
  # Uses default provider (us-east-1)
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}

resource "aws_instance" "west" {
  provider = aws.west  # Explicitly uses us-west-2
  ami      = "ami-87654321"
  instance_type = "t3.micro"
}
```

---

## The configuration_aliases Declaration

When building reusable modules, you need to declare which provider configurations your module expects. This is where `configuration_aliases` comes in.

### Why configuration_aliases?

Without `configuration_aliases`, Terraform assumes your module will use the default provider configuration. But for multi-cloud or multi-region scenarios, you need to:

1. **Declare** that your module accepts specific provider aliases
2. **Wire** those providers from the root module to the child module

### Syntax in Modules

In your module's provider configuration block:

```hcl
# modules/my-module/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws.primary,
        aws.secondary
      ]
    }
  }
}

# Now this module expects two AWS provider configurations
resource "aws_vpc" "primary" {
  provider   = aws.primary
  cidr_block = "10.0.0.0/16"
}

resource "aws_vpc" "secondary" {
  provider   = aws.secondary
  cidr_block = "10.1.0.0/16"
}
```

### Wiring Providers with the providers Map

In your root module, you pass provider configurations to child modules using the `providers` map:

```hcl
# root main.tf

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

module "infrastructure" {
  source = "./modules/my-module"

  providers = {
    aws.primary   = aws.east
    aws.secondary = aws.west
  }
}
```

**Key points:**

- The left side (`aws.primary`, `aws.secondary`) matches the aliases declared in `configuration_aliases`
- The right side (`aws.east`, `aws.west`) references the providers defined in your root module
- This creates an explicit mapping between your module's expectations and your root configuration

---

## Quick Start: Docker Provider Example

Let's start with a simple, practical example using the Docker provider to demonstrate the pattern before diving into more complex scenarios.

### Scenario

You want to deploy containers to two different Docker hosts: a development server and a staging server.

### Step 1: Module Setup

```hcl
# modules/docker-app/versions.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
      configuration_aliases = [docker.target]
    }
  }
}
```

```hcl
# modules/docker-app/main.tf

variable "app_name" {
  type = string
}

variable "image" {
  type = string
}

variable "port" {
  type    = number
  default = 8080
}

resource "docker_image" "app" {
  provider = docker.target
  name     = var.image
}

resource "docker_container" "app" {
  provider = docker.target
  name     = var.app_name
  image    = docker_image.app.image_id

  ports {
    internal = var.port
    external = var.port
  }

  restart = "unless-stopped"
}
```

### Step 2: Root Configuration

```hcl
# main.tf

provider "docker" {
  alias = "dev"
  host  = "tcp://dev-docker-host:2376"
}

provider "docker" {
  alias = "staging"
  host  = "tcp://staging-docker-host:2376"
}

module "dev_app" {
  source = "./modules/docker-app"

  providers = {
    docker.target = docker.dev
  }

  app_name = "myapp-dev"
  image    = "nginx:latest"
  port     = 8080
}

module "staging_app" {
  source = "./modules/docker-app"

  providers = {
    docker.target = docker.staging
  }

  app_name = "myapp-staging"
  image    = "nginx:latest"
  port     = 8080
}
```

### What's Happening?

1. The module declares it needs a `docker.target` provider configuration
2. We define two Docker providers (`dev` and `staging`) with different hosts
3. We instantiate the module twice, mapping `docker.target` to different providers each time
4. Same module code deploys to two different Docker hosts

**Run it:**

```bash
terraform init
terraform plan
terraform apply
```

You'll see Terraform create containers on both Docker hosts using the same module definition.

---

## Advanced: EKS + Kubernetes Multi-Provider Setup

Now let's tackle a real-world scenario: deploying an EKS cluster and immediately configuring Kubernetes resources within it. This requires coordinating three providers: AWS (for EKS), AWS (for other resources), and Kubernetes (for cluster resources).

### The Challenge

When you create an EKS cluster, you need the cluster endpoint and authentication token to configure the Kubernetes provider. But Terraform evaluates provider configurations before resources are created. This is the classic "chicken and egg" problem.

**Solution:** Use provider aliases and data sources to dynamically configure providers after resource creation.

### Architecture Overview

```
Root Module
├── AWS Provider (default) → VPC, networking
├── AWS Provider (eks) → EKS cluster
└── Kubernetes Provider → Deployments, services (after EKS exists)
    ↓
Module: EKS + K8s Resources
├── Uses aws.eks provider
└── Uses kubernetes provider
```

### Step 1: EKS Module Setup

```hcl
# modules/eks-app/versions.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.eks]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
      configuration_aliases = [kubernetes.eks]
    }
  }
}
```

```hcl
# modules/eks-app/variables.tf

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_instance_types" {
  description = "Instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}
```

```hcl
# modules/eks-app/main.tf

# EKS Cluster
resource "aws_eks_cluster" "main" {
  provider = aws.eks
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_resource_controller,
  ]
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "cluster" {
  provider = aws.eks
  name     = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  provider   = aws.eks
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
  provider   = aws.eks
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# Node Group
resource "aws_eks_node_group" "main" {
  provider        = aws.eks
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_desired_size + 2
    min_size     = 1
  }

  instance_types = var.node_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.registry_policy,
  ]
}

# IAM Role for Node Group
resource "aws_iam_role" "node" {
  provider = aws.eks
  name     = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  provider   = aws.eks
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  provider   = aws.eks
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  provider   = aws.eks
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# Kubernetes Resources
resource "kubernetes_namespace" "app" {
  provider = kubernetes.eks

  metadata {
    name = "my-app"
    labels = {
      environment = "production"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "kubernetes_deployment" "app" {
  provider = kubernetes.eks

  metadata {
    name      = "my-app"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "my-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "my-app"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.25"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.app]
}

resource "kubernetes_service" "app" {
  provider = kubernetes.eks

  metadata {
    name      = "my-app-service"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app = "my-app"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment.app]
}
```

```hcl
# modules/eks-app/outputs.tf

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "load_balancer_hostname" {
  description = "Hostname of the LoadBalancer service"
  value       = kubernetes_service.app.status[0].load_balancer[0].ingress[0].hostname
}
```

### Step 2: Root Module Configuration

```hcl
# main.tf

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Default AWS provider for general resources
provider "aws" {
  region = var.aws_region
}

# Separate AWS provider for EKS
provider "aws" {
  alias  = "eks"
  region = var.aws_region
}

# Data sources to get cluster info for Kubernetes provider
data "aws_eks_cluster" "cluster" {
  name = module.eks_app.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_app.cluster_name
}

# Kubernetes provider configured to use the EKS cluster
provider "kubernetes" {
  alias                  = "eks_cluster"
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# EKS Module
module "eks_app" {
  source = "./modules/eks-app"

  providers = {
    aws.eks        = aws.eks
    kubernetes.eks = kubernetes.eks_cluster
  }

  cluster_name        = var.cluster_name
  cluster_version     = "1.28"
  subnet_ids          = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
  node_desired_size   = 2
  node_instance_types = ["t3.medium"]
}
```

```hcl
# variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}
```

```hcl
# outputs.tf

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks_app.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_app.cluster_name
}

output "load_balancer_hostname" {
  description = "Application load balancer hostname"
  value       = module.eks_app.load_balancer_hostname
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_app.cluster_name}"
}
```

### Step 3: Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Configure kubectl to access your cluster
aws eks update-kubeconfig --region us-east-1 --name my-eks-cluster

# Verify Kubernetes resources
kubectl get namespaces
kubectl get deployments -n my-app
kubectl get services -n my-app
```

### What's Happening?

1. **VPC and networking** are created using the default AWS provider
2. **EKS cluster** is created using the `aws.eks` provider alias
3. **Data sources** fetch cluster endpoint and auth token after cluster creation
4. **Kubernetes provider** is dynamically configured with cluster credentials
5. **Module** receives both providers via the `providers` map
6. **Kubernetes resources** are deployed to the newly created cluster

The key insight: the Kubernetes provider depends on outputs from the EKS cluster, but we use data sources to bridge that gap.

---

## Best Practices

### 1. Always Declare configuration_aliases

Make your module's provider requirements explicit:

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.primary]
    }
  }
}
```

### 2. Use Descriptive Alias Names

Choose names that clearly indicate purpose:

```hcl
# Good
provider "aws" {
  alias = "production"
}

provider "aws" {
  alias = "disaster_recovery"
}

# Less clear
provider "aws" {
  alias = "a"
}

provider "aws" {
  alias = "b"
}
```

### 3. Document Provider Requirements

Add clear documentation to your module's README:

```markdown
## Provider Requirements

This module requires two AWS provider configurations:

- `aws.primary`: Primary region for main resources
- `aws.backup`: Backup region for disaster recovery

Example:

```hcl
provider "aws" {
  alias  = "main"
  region = "us-east-1"
}

provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

module "app" {
  source = "./modules/app"
  
  providers = {
    aws.primary = aws.main
    aws.backup  = aws.dr
  }
}
```
```

### 4. Use Data Sources for Dynamic Providers

When provider configuration depends on resource outputs, use data sources:

```hcl
# Create cluster first
resource "aws_eks_cluster" "main" {
  # ...
}

# Fetch cluster info
data "aws_eks_cluster" "main" {
  name = aws_eks_cluster.main.name
}

# Configure provider with fetched data
provider "kubernetes" {
  host  = data.aws_eks_cluster.main.endpoint
  token = data.aws_eks_cluster_auth.main.token
  # ...
}
```

### 5. Manage State Carefully

With multiple providers, consider:

- Separate state files for different environments
- Remote state with locking
- State isolation between critical components

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "production/eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### 6. Test Provider Connectivity

Add a simple data source to verify provider configuration:

```hcl
data "aws_caller_identity" "current" {
  provider = aws.eks
}

output "eks_account_id" {
  value = data.aws_caller_identity.current.account_id
}
```

---

## Conclusion

Provider aliases and the `configuration_aliases` pattern unlock powerful multi-cloud and multi-region capabilities in Terraform:

- **Flexibility**: Deploy resources anywhere without duplicating code
- **Modularity**: Build reusable modules that work across providers
- **Coordination**: Chain providers together (EKS → Kubernetes)
- **Organization**: Separate concerns by provider configuration

**Key takeaways:**

1. Use `configuration_aliases` to declare provider requirements in modules
2. Wire providers with the `providers` map in root modules
3. Start simple (Docker example) before tackling complex scenarios (EKS)
4. Use data sources to bridge provider dependencies
5. Document your provider requirements clearly

The pattern might seem complex at first, but it's essential for managing real-world infrastructure. Start with the Docker example, understand the mechanics, then apply it to more sophisticated deployments.

### Further Reading

- [Terraform Provider Configuration](https://developer.hashicorp.com/terraform/language/providers/configuration)
- [Module Providers](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

*Have questions or suggestions? Open an issue or submit a PR to this repository!*
