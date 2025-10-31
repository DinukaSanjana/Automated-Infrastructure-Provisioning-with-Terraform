resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow SSH access from within the VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.VpcCIDR]  # This allows SSH access from within the VPC
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
  key_name = "KEY_NAME"

user_data = <<-EOF
#!/bin/bash

# Update package lists
sudo apt update
sudo apt install nginx -y

# Install prerequisites for adding repositories securely
sudo apt install -y apt-transport-https ca-certificates curl

# Add Docker's official GPG key securely using HTTPS
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add the Docker repository to Apt sources
echo "deb [arch=$(dpkg   
 --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list   


# Update package lists   
 again (to reflect the new repository)
sudo apt update

# Install Docker engine, CLI, containerd, buildx plugin, and compose plugin
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker installation
sudo docker run -d -p 80:80 nginx   


# Optionally, add your user (e.g., 'ubuntu') to the docker group for non-sudo Docker commands
# (This step requires manual login and logout after instance launch)
# sudo usermod -a -G docker ubuntu

EOF

  tags = {
    Name = "MyPrivateInstance"
  }
}