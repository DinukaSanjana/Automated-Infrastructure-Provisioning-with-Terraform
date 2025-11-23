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
