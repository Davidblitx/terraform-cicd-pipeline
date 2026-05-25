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
    iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

    # user_data runs automatically when the server first boots
    # This installs everything your server needs
    user_data = <<EOF
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

echo "=== BOOTSTRAP STARTED: $(date) ==="

# ── STEP 1: System update ─────────────────────────────────
echo "--- Updating system..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget unzip git ufw fail2ban \
  unattended-upgrades bc

# ── STEP 2: Create non-root user ─────────────────────────
echo "--- Creating devops user..."
if ! id "devops" &>/dev/null; then
  adduser --disabled-password --gecos "" devops
  usermod -aG sudo devops
  mkdir -p /home/devops/.ssh
  cp /home/ubuntu/.ssh/authorized_keys /home/devops/.ssh/
  chown -R devops:devops /home/devops/.ssh
  chmod 700 /home/devops/.ssh
  chmod 600 /home/devops/.ssh/authorized_keys
fi

# ── STEP 3: Harden SSH ────────────────────────────────────
echo "--- Hardening SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' \
  /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' \
  /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' \
  /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' \
  /etc/ssh/sshd_config
sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' \
  /etc/ssh/sshd_config
echo "AllowUsers ubuntu devops" >> /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
echo "LoginGraceTime 60" >> /etc/ssh/sshd_config
systemctl restart sshd

# ── STEP 4: Configure UFW firewall ───────────────────────
echo "--- Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

# ── STEP 5: Configure Fail2Ban ───────────────────────────
echo "--- Configuring Fail2Ban..."
cat > /etc/fail2ban/jail.local << 'FAIL2BAN'
[sshd]
enabled = true
maxretry = 3
findtime = 600
bantime = 3600
FAIL2BAN
systemctl enable fail2ban
systemctl restart fail2ban

# ── STEP 6: Automatic security updates ───────────────────
echo "--- Enabling automatic updates..."
echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' \
  > /etc/apt/apt.conf.d/20auto-upgrades

# ── STEP 7: Install Docker ───────────────────────────────
echo "--- Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
usermod -aG docker devops
systemctl enable docker
systemctl start docker
timeout 30 bash -c 'until docker info; do sleep 2; done'
echo "Docker ready"

# ── STEP 8: Install Nginx ────────────────────────────────
echo "--- Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# ── STEP 9: Configure Nginx reverse proxy ────────────────
echo "--- Configuring Nginx..."
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/flask-app << 'NGINX'
limit_req_zone $binary_remote_addr zone=app_limit:10m rate=10r/s;

server {
    listen 80;
    server_name _;
    server_tokens off;

    access_log /var/log/nginx/flask-app.access.log;
    error_log  /var/log/nginx/flask-app.error.log warn;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        limit_req zone=app_limit burst=20 nodelay;
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }
}
NGINX
ln -s /etc/nginx/sites-available/flask-app \
  /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# ── STEP 10: Install AWS CLI v2 ──────────────────────────
echo "--- Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# ── STEP 11: Create monitoring structure ─────────────────
echo "--- Setting up monitoring..."
mkdir -p /var/log/app-monitor
chown devops:devops /var/log/app-monitor
touch /var/log/app-monitor/health.log
touch /var/log/app-monitor/alerts.log
touch /var/log/app-monitor/deployments.log

# ── STEP 12: Create app directory ────────────────────────
mkdir -p /home/ubuntu/app
chown ubuntu:ubuntu /home/ubuntu/app
mkdir -p /home/devops/scripts
chown devops:devops /home/devops/scripts

echo "=== BOOTSTRAP COMPLETE: $(date) ===" \
  > /var/log/bootstrap-complete.log
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


# ============================================================
# IAM LAYER
# ============================================================

# Step 1: The role itself
# Think of this as creaing a job title
# "EC2 server" is the job title
# The assume_role_policy says: "only EC2 services can hold this title"
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

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

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# S	tep 2: The policy — what the role is allowed to do
# This is the job description
# It says: "whoever holds this title can do these specific things in ECR"
resource "aws_iam_role_policy" "ecr_policy" {
  name = "${var.project_name}-ecr-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Get a login token to authenticate with ECR
          "ecr:GetAuthorizationToken",
          # Pull image layers
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          # Check if image exists
          "ecr:BatchCheckLayerAvailability",
          # List images (useful for debugging)
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# Step 3: Instance profile
# This is the bridge between the role and the EC2 instance
# EC2 cannot directly use a role — it needs an instance profile wrapper
# Think of it as the physical ID card that holds the job title
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
