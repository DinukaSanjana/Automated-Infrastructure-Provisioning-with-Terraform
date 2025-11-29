# Project - Automated Infrastructure Provisioning with Terraform

## Overview
Terraform → Infrastructure as Code (IaC) using HCL (HashiCorp Configuration Language)  
`.tfstate` file → Records the current state of all managed resources  
Terraform uses AWS CLI credentials to authenticate and connect to your AWS account

## Architecture
- Region: ap-south-1 (Mumbai)
- 3 Availability Zones for High Availability
- Each AZ contains:
  - 1 Public Subnet → Hosts Application Load Balancer (ALB) and NAT Gateway
  - 1 Private Subnet → Hosts NGINX EC2 instance (completely isolated, no public IP)
- Inbound Traffic Flow:  
  Internet → ALB (Public Subnet) → NGINX EC2 (Private Subnet on Port 80)
- Outbound Traffic Flow:  
  NGINX EC2 (Private) → NAT Gateway (Public Subnet) → Internet

## Prerequisites & Setup Commands

| Command                          | Purpose |
|----------------------------------|---------------------------------------------------------------------|
| `Install AWS CLI v2`             | Required to interact with AWS from local machine or EC2 |
| `Install Terraform`              | Main IaC tool to provision infrastructure |
| `aws configure`                  | Stores Access Key, Secret Key, default region, output format |
| `aws s3 ls`                      | Simple test to verify AWS credentials are working |
| `git clone <repository-url>`     | Download the Terraform project files |
| `terraform init`                 | Initializes project: downloads AWS provider plugin + VPC module |
| `terraform plan`                 | Dry-run: shows exactly what resources (e.g., ~30) will be created |
| `terraform apply`                | Actually creates all resources on AWS (VPC, subnets, NAT, ALB, EC2) |
| `terraform destroy`              | Deletes everything created by this project (clean teardown) |

## Terraform Configuration Files

### providers.tf
```hcl
provider "aws" {
  region = var.AWS_REGION
}
```
<!--

### vars.tf
```hcl
variable "AWS_REGION" { default = "ap-south-1" }
variable "VPC_NAME" {}
variable "VpcCIDR" {}
variable "Zone1" {}
variable "Zone2" {}
variable "Zone3" {}
variable "PubSub1CIDR" {}
variable "PubSub2CIDR" {}
variable "PubSub3CIDR" {}
variable "PrivSub1CIDR" {}
variable "PrivSub2CIDR" {}
variable "PrivSub3CIDR" {}
variable "AMI_ID" {}
variable "MYIP" {}
```

### vpc.tf (Using Official Terraform Module)
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.VPC_NAME
  cidr = var.VpcCIDR

  azs             = [var.Zone1, var.Zone2, var.Zone3]
  private_subnets = [var.PrivSub1CIDR, var.PrivSub2CIDR, var.PrivSub3CIDR]
  public_subnets  = [var.PubSub1CIDR, var.PubSub2CIDR, var.PubSub3CIDR]

  enable_nat_gateway = true
  single_nat_gateway = true   # Cost-effective for learning
}
```

### instance.tf
```hcl
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow HTTP from VPC & SSH from MyIP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.VpcCIDR]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.MYIP}/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_ec2" {
  ami           = var.AMI_ID
  instance_type = "t2.medium"
  subnet_id     = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = "your-key-pair"

  user_data = <<-EOT
    #!/bin/bash
    apt update -y
    apt install docker.io -y
    systemctl start docker
    systemctl enable docker
    docker run -d -p 80:80 nginx
  EOT

  tags = { Name = "NGINX-Private-Instance" }
}
```

### lb.tf
```hcl
resource "aws_lb" "my_alb" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_security_group" "alb_sg" {
  name   = "alb_sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.my_ec2.id
  port             = 80
}
```

-->

## Deployment Steps
```bash
git clone <your-repo>
cd project-folder
terraform init
terraform plan
terraform apply    # type "yes" when prompted
```

## Verification
1. Go to AWS Console → EC2 → Load Balancers
2. Select `my-load-balancer`
3. Copy the DNS name (e.g., my-load-balancer-1234567890.ap-south-1.elb.amazonaws.com)
4. Paste in browser → You should see "Welcome to nginx!"

## Security Validation (Advanced Test)
- Direct SSH to private NGINX instance from internet → fails (no public IP)
- Launch a temporary Bastion Host in public subnet
- SSH into Bastion → then SSH to private NGINX instance using private IP
→ Proves the instance is fully isolated from the internet

## Cleanup
```bash
terraform destroy   # type "yes" to confirm
```

Project Complete – Fully automated, secure, highly available NGINX deployment using Terraform IaC.
