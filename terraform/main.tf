# ============================================================
# NETWORKING LAYER
# ============================================================

# VPC - your private network
resource "aws_vpc" "main" {
    cidr_block           = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = {
        Name = "${var.project_name}-vpc"
    }
}


# Internet Gateway - the door to the Internet
resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "${var.project_name}-igw"
    }
}

# Public Subnet - where your EC2 will live
resource "aws_subnet" "public" {
    vpc_id                  = aws_vpc.main.id
    cidr_block              = var.public_subnet_cidr
    availability_zone       = "${var.aws_region}a"
    map_public_ip_on_launch = true

    tags = {
        Name = "${var.project_name}-public-subnet"
    }
}

# Route Table - traffic rules
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    # Send all internet-bound traffic through the Internet Gateway
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
    
    tags = {
        Name = "${var.project_name}-public-rt"
    }
}

# Associate the route table with the subnet
# Without this, the subnet doesn't know to use these rules
resource "aws_route_table_association" "public" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}

# ============================================================
# SECURITY LAYER
# ============================================================

resource "aws_security_group" "web_server" {
    name        = "${var.project_name}-web-sg"
    description = "Security group for web server"
    vpc_id      = aws_vpc.main.id

    # SSH - only from your IP
    ingress {
        description = "SSH from my IP only"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.allowed_ssh_cidr]
    } 

    # HTTP - public
    ingress {
        description = "HTTP from Internet"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTPS - public
    ingress {
        description = "HTTPS from the Internet"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # All outbound traffic allowed 
    egress {
        description = "All outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-web-sg"
    }
}


# ============================================================
# COMPUTE LAYER
# ============================================================

resource "aws_instance" "web_server" {
    ami                    = var.ami_id
    instance_type          = var.instance_type
    subnet_id              = aws_subnet.public.id
    vpc_security_group_ids = [aws_security_group.web_server.id]
    key_name               = var.ssh_key_name

    # user_data runs automatically when the server first boots
    # This installs everything your server needs
    user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1

    echo "=== Starting bootstrap at $(date) ==="

    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget unzip git

    echo "=== Installing Docker ==="
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker ubuntu
    systemctl enable docker
    systemctl start docker

    timeout 30 bash -c 'until docker info; do sleep 2; done'
    echo "Docker is ready"

    echo "=== Installing Nginx ==="
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx

    echo "=== Installing AWS CLI ==="
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
      -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/

    mkdir -p /home/ubuntu/app
    chown ubuntu:ubuntu /home/ubuntu/app

    echo "=== Bootstrap complete at $(date) ===" > /var/log/bootstrap-complete.log
  EOF  

  tags = {
    Name = "${var.project_name}-web-server"
  }
}


# ============================================================
# CONTAINER REGISTRY
# ============================================================

# ECR repository - where your Docker Images will be stored
resource "aws_ecr_repository" "app" {
    name                 = "${var.project_name}-app"
    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }

    tags = {
        Name = "${var.project_name}-ecr"
    }
}
