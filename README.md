# Project  - Automated Infrastructure Provisioning with Terraform

## Aim
The aim of this project is to automate the provisioning of a secure and scalable cloud infrastructure using Terraform. The setup includes creating secure VPCs with high availability. This Terraform configuration streamlines the deployment process, ensuring a robust and efficient infrastructure environment.

## Tools Installation
- Install AWS CLI version 2
- Install Terraform
- aws configure
- aws s3 ls
- Use git clone for project file

## Architecture
- VPC in ap-south-1 region
- High Availability with 3 AZs
- Subnets: 3 Public, 3 Private
- NGINX on EC2 in Private Subnet
- No Public IP
- User Data script for NGINX install
- Connectivity:
  - Inbound: Users to ALB in Public Subnet, forward to NGINX in Private Subnet
  - Outbound: NGINX to NAT Gateway in Public Subnet to Internet

## Terraform Files

### providers.tf
```hcl
provider "aws" {
  region = var.AWS_REGION
}
```

### vars.tf
```hcl
variable "AWS_REGION" {}
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

### vpc.tf
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.VPC_NAME
  cidr = var.VpcCIDR

  azs              = [var.Zone1, var.Zone2, var.Zone3]
  private_subnets  = [var.PrivSub1CIDR, var.PrivSub2CIDR, var.PrivSub3CIDR]
  public_subnets   = [var.PubSub1CIDR, var.PubSub2CIDR, var.PubSub3CIDR]

  enable_nat_gateway = true
  single_nat_gateway = true
}
```

### instance.tf
```hcl
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow HTTP from VPC and SSH from MyIP"
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
    cidr_blocks = [var.MYIP]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2_sg"
  }
}

resource "aws_instance" "my_ec2" {
  ami           = var.AMI_ID
  instance_type = "t2.medium"
  subnet_id     = module.vpc.private_subnets[0]

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = "KEY_NAME"

  user_data = <<-EOT
    #!/bin/bash
    
    # Update package lists
    sudo apt update
    
    # Install prerequisites for adding repositories securely
    sudo apt install -y ca-certificates curl
    
    # Create directory for GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Add Docker's official GPG key
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add the Docker repository to Apt sources
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package lists again (to reflect the new repository)
    sudo apt update
    
    # Install Docker engine, CLI, containerd, buildx plugin, and compose plugin
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Verify Docker installation by running the Nginx container
    sudo docker run -d -p 80:80 nginx
  EOT

  tags = {
    Name = "MyPrivateInstance"
  }
}
```

### lb.tf
```hcl
resource "aws_lb" "my_lb" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name = "my-load-balancer"
  }
}

resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow HTTP and HTTPS traffic to the load balancer"
  vpc_id      = module.vpc.vpc_id

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

  tags = {
    Name = "lb_sg"
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold    = 2
    unhealthy_threshold  = 2
  }

  tags = {
    Name = "my-target-group"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

resource "aws_lb_target_group_attachment" "ec2_attachment" {
  count             = 1
  target_group_arn  = aws_lb_target_group.my_target_group.arn
  target_id         = aws_instance.my_ec2.id
  port              = 80
}
```

### out.tf
```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}
```

## Deployment
1. terraform init
2. terraform plan
3. terraform apply

## Verification
- AWS Console > Load Balancer > Copy DNS Name
- Paste in web browser

## Advanced Test
- Launch Bastion Host in Public Subnet with Public IP
- SSH to Bastion Host
- From Bastion, SSH to NGINX instance using Private IP (Port 22 allowed in Security Group)
