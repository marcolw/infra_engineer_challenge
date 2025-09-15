terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "infra-terraform-state-20250910"  # UPDATE THIS (must be globally unique)
    key            = "infra/terraform.tfstate"
    region         = "ap-southeast-2"
    use_lockfile = true 
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "infra-challenge"
      Environment = "demo"
      Owner       = "marco-liao"
      ManagedBy   = "terraform"
    }
  }
}

# IAM role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "ssm-ec2-role" #-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-instance-profile" #-${random_id.suffix.hex}"
  role = aws_iam_role.ssm_role.name
}

# Network configuration

# Create a new VPC with public subnets
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "challenge-vpc"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "challenge-igw"
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Create route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate route table with public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group - HTTP/HTTPS only
resource "aws_security_group" "web_sg" {
  name        = "web-sg" #-${random_id.suffix.hex}"
  description = "Security group for web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-security-group"
  }
}

# Ubuntu AMI lookup
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# External script to check keypair existence
data "external" "keypair_check" {
  program = ["bash", "${path.module}/../scripts/check_keypair.sh", var.key_name]
}


# Generate new key only if missing
resource "tls_private_key" "ec2_key" {
  #count     = data.external.keypair_check.result.exists == "false" ? 1 : 0
  algorithm = "ED25519"
}

resource "aws_key_pair" "generated" {
  # count      = data.external.keypair_check.result.exists == "false" ? 1 : 0
  key_name   = var.key_name
  public_key = tls_private_key.ec2_key.public_key_openssh #
}

# Save private key only if new keypair created
resource "aws_secretsmanager_secret" "ssh_private_key" {
  # count       = length(aws_key_pair.generated) > 0 ? 1 : 0
  name        = "ec2-ssh-private-key"
  description = "SSH private key for EC2 instance access"
}

resource "aws_secretsmanager_secret_version" "ssh_private_key_version" {
  # count         = length(aws_secretsmanager_secret.ssh_private_key) > 0 ? 1 : 0
  secret_id     = aws_secretsmanager_secret.ssh_private_key.id #
  secret_string = tls_private_key.ec2_key.private_key_openssh #
}

# Decide final key name (either existing or generated)
# locals {
#   final_key_name = data.external.keypair_check.result.exists == "true" ? var.key_name : aws_key_pair.generated[0].key_name
# }

# EC2 instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name = aws_key_pair.generated.key_name # #
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  associate_public_ip_address = true

  user_data = file("${path.module}/cloud-init.yaml")

  tags = {
    Name        = "infra-challenge-webserver"
    Description = "Web server for infrastructure challenge"
  }
}

# Save EC2 public IP to SSM Parameter Store
resource "aws_ssm_parameter" "web_ip" {
  name  = "/ec2/web/public_ip"
  type  = "String"
  value = aws_instance.web.public_ip
}

