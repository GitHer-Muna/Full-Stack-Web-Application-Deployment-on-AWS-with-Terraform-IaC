# Full-Stack Web Application Deployment on AWS with Terraform

**A hands-on DevOps project deploying a Node.js bookstore application on AWS using Terraform**

---

## Introduction

Hey there! Welcome to this DevOps project where we'll deploy a real-world full-stack web application on AWS using Terraform.

This project demonstrates a complete DevOps workflow: deploying a full-stack Node.js application on AWS using Terraform for Infrastructure as Code (IaC). Everything from VPC creation to application deployment is automated - no manual AWS Console clicking required.

**By the end of this blog, you'll have:**
- ✅ A production-ready Node.js application running on AWS
- ✅ Complete infrastructure automated with Terraform (Infrastructure as Code)
- ✅ A portfolio project to showcase your DevOps skills
- ✅ Hands-on experience with AWS, Terraform, Linux, Nginx, and systemd
- ✅ Real troubleshooting experience

**Application:** TheEpicBook - an online bookstore  
**Source:** https://github.com/pravinmishraaws/theepicbook  
**Tech Stack:** Node.js, Express, MySQL, Nginx  
**Cloud:** AWS  
**IaC Tool:** Terraform  

---

## Architecture Overview

Here's what we're building:

```
                    Internet
                       │
                       ▼
              [Elastic IP]
                       │
┌──────────────────────┼─────────────────────────────────────┐
│                      ▼         AWS VPC (10.0.0.0/16)       │
│                                                             │
│  ┌──────────────────┐       ┌──────────────────────────┐  │
│  │  Public Subnet   │       │  Private Subnets         │  │
│  │  10.0.1.0/24     │       │  10.0.2.0/24 (AZ-1a)    │  │
│  │  (us-east-1a)    │       │  10.0.3.0/24 (AZ-1b)    │  │
│  │                  │       │                          │  │
│  │  ┌────────────┐  │       │  ┌────────────────────┐ │  │
│  │  │ EC2        │  │       │  │ RDS MySQL          │ │  │
│  │  │ t2.micro   │──┼───────┼──│ db.t3.micro        │ │  │
│  │  │ Ubuntu     │  │ 3306  │  │ MySQL 8.0          │ │  │
│  │  │ Node.js    │  │       │  │ 20GB gp3           │ │  │
│  │  │ Nginx:80   │  │       │  └────────────────────┘ │  │
│  │  └─────┬──────┘  │       │                          │  │
│  │        │ EIP     │       │  (Multi-AZ ready)        │  │
│  └────────┼─────────┘       └──────────────────────────┘  │
│           │                                                │
│    ┌──────▼──────┐                                        │
│    │   Internet  │                                        │
│    │   Gateway   │                                        │
│    └─────────────┘                                        │
└────────────────────────────────────────────────────────────┘
```

**Traffic Flow:**
1. User → Elastic IP:80 → Nginx
2. Nginx → Node.js:8080
3. Node.js → RDS MySQL:3306 (private network)

**Key Components:**

| Component | Count | Details |
|-----------|-------|---------|
| VPC | 1 | 10.0.0.0/16 with DNS enabled |
| Subnets | 3 | 1 public, 2 private (Multi-AZ) |
| Internet Gateway | 1 | For public internet access |
| Route Tables | 1 | Routes 0.0.0.0/0 to IGW |
| Security Groups | 2 | EC2 (SSH/HTTP/8080), RDS (MySQL:3306) |
| EC2 Instance | 1 | t2.micro, Ubuntu 22.04, 20GB gp3 |
| Elastic IP | 1 | Static public IP |
| SSH Key Pair | 1 | Secure access |
| RDS Instance | 1 | MySQL 8.0, db.t3.micro, 20GB gp3 |
| RDS Subnet Group | 1 | Multi-AZ support |
| **TOTAL** | **14 resources** | **One command!** |

---

## Prerequisites

Before we start, make sure you have:
- AWS Account (free tier works fine) - [Sign up here](https://aws.amazon.com/free/)
- AWS CLI installed and configured
- Terraform installed (v1.0 or later)
- SSH client
- A code editor (VS Code recommended)
- Git

### Tools Installation

**1. AWS CLI**
```bash
# For Linux/macOS
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

**2. Terraform**
```bash
# For macOS
brew install terraform

# For Linux
wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform --version
```

**3. Git**
```bash
# Most systems have this pre-installed
git --version

# If not installed:
# macOS: brew install git
# Linux: sudo apt-get install git -y
```

---

## Step-by-Step Implementation

### Part 1: Setting Up Your Environment

**Step 1.1: Create the Project Directory**

```bash
# Create project folder
mkdir aws-terraform-deployment
cd aws-terraform-deployment

# Create subdirectories
mkdir terraform scripts

# Verify structure
tree .
# Output:
# .
# ├── terraform
# └── scripts
```

**Step 1.2: Initialize Git Repository**

```bash
git init
```

**Step 1.3: Configure AWS CLI**

```bash
aws configure
```

You'll be prompted to enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json recommended)

**⚠️ Important:** Never commit these credentials to Git or share them publicly.

**Step 1.4: Verify AWS Configuration**

```bash
aws sts get-caller-identity
```

If this returns your AWS account details, you're good to go!

**Step 1.5: Generate SSH Key for EC2**

```bash
# Create a new key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/epicbook-key -N ""

# Verify keys were created
ls -la ~/.ssh/epicbook-key*

# Set proper permissions
chmod 400 ~/.ssh/epicbook-key
```

What are these?
- `epicbook-key` - Private key (keep secret!)
- `epicbook-key.pub` - Public key (uploads to AWS)

---

### Part 2: Create Terraform Files

Navigate to the terraform directory:

```bash
cd terraform
```

**Step 2.1: Create main.tf**

```hcl
# Terraform Configuration
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

**What this does:**
- Sets Terraform version requirement
- Configures AWS provider
- Adds default tags to all resources

**Step 2.2: Create variable.tf**

```hcl
# General Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "epicbook"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Network Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "us-east-1a"
}

# EC2 Variables
variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

# RDS Variables
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "epicbookdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# Application Variables
variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8080
}
```

**Step 2.3: Create vpc.tf**

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
    Type        = "Public"
  }
}

# Private Subnet 1
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name        = "${var.project_name}-private-subnet"
    Environment = var.environment
    Type        = "Private"
  }
}

# Private Subnet 2 (for RDS Multi-AZ requirement)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-private-subnet-2"
    Environment = var.environment
    Type        = "Private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

**What this creates:**
- VPC (your private cloud network)
- 3 subnets (1 public, 2 private)
- Internet gateway (for internet access)
- Route table (directs traffic)

**Step 2.4: Create security-groups.tf**

```hcl
# EC2 Security Group
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port
  ingress {
    description = "Application port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - allow all
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id

  # MySQL access only from EC2 security group
  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Outbound - allow all
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}
```

**What this creates:**
- EC2 firewall (allows SSH, HTTP, app port)
- RDS firewall (allows MySQL only from EC2)

**Step 2.5: Create ec2.tf**

```hcl
# SSH Key Pair
resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = file("~/.ssh/epicbook-key.pub")

  tags = {
    Name        = "${var.project_name}-key"
    Environment = var.environment
  }
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public.id

  user_data = templatefile("${path.module}/../scripts/user-data.sh", {
    db_host     = aws_db_instance.main.address
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
    app_port    = var.app_port
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }

  depends_on = [aws_db_instance.main]
}

# Elastic IP
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name        = "${var.project_name}-eip"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}
```

**What this creates:**
- SSH key pair in AWS
- EC2 instance with automated setup
- Static IP address (Elastic IP)

**Step 2.6: Create rds.tf**

```hcl
# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id]

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier           = "${var.project_name}-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  storage_type         = "gp3"
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  publicly_accessible = false
  skip_final_snapshot = true

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  tags = {
    Name        = "${var.project_name}-rds"
    Environment = var.environment
  }
}
```

**What this creates:**
- MySQL database in private subnet
- Automated backups (7-day retention)
- 20GB gp3 storage

**Step 2.7: Create output.tf**

```hcl
# EC2 Outputs
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.app.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.app.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ~/.ssh/epicbook-key ubuntu@${aws_eip.app.public_ip}"
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.main.address
}

# Application Output
output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_eip.app.public_ip}"
}

# Network Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [aws_subnet.private.id, aws_subnet.private_2.id]
}
```

**Step 2.8: Create terraform.tfvars**

```hcl
key_name    = "epicbook-key"
db_password = "EpicBook2024SecurePass"
```

**⚠️ Important:** 
- Never commit this file to Git
- Use a strong password
- RDS doesn't allow `/`, `@`, `"`, or spaces in passwords

---

### Part 3: Create User Data Script

Create `scripts/user-data.sh`:

```bash
#!/bin/bash
set -e

# Update system
apt-get update -y
apt-get upgrade -y

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Git, Nginx, MySQL client
apt-get install -y git nginx mysql-client

# Clone the application
cd /home/ubuntu
git clone https://github.com/pravinmishraaws/theepicbook.git
cd theepicbook

# Create .env file
cat > .env << ENVEOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
PORT=${app_port}
ENVEOF

# Install application dependencies
npm install

# Configure Nginx as reverse proxy
cat > /etc/nginx/sites-available/default << NGINXEOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:${app_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINXEOF

# Restart Nginx
systemctl restart nginx
systemctl enable nginx

# Create systemd service
cat > /etc/systemd/system/epicbook.service << SERVICEEOF
[Unit]
Description=EpicBook Node.js Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/theepicbook
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/theepicbook

# Start the application
systemctl daemon-reload
systemctl enable epicbook
systemctl start epicbook

sleep 30
```

**What this script does:**
1. Installs Node.js, Git, Nginx, MySQL client
2. Clones the application from GitHub
3. Creates environment configuration
4. Sets up Nginx reverse proxy
5. Creates systemd service
6. Starts everything automatically

---

### Part 4: Deploy Everything with Terraform

**Step 4.1: Initialize Terraform**

```bash
cd terraform
terraform init
```

This downloads the AWS provider plugin.

**Step 4.2: Validate Configuration**

```bash
terraform validate
```

Expected output: `Success! The configuration is valid.`

**Step 4.3: Plan the Deployment**

```bash
terraform plan
```

You'll see a list of ~14 resources to be created.

**Step 4.4: Apply the Configuration**

```bash
terraform apply
```

Type `yes` when prompted. This takes 10-15 minutes.

**Step 4.5: Save Outputs**

```bash
terraform output > deployment-info.txt
cat deployment-info.txt
```

---

### Part 5: Verify Deployment

**Step 5.1: SSH into EC2**

```bash
# Get SSH command
terraform output ssh_command

# Connect
ssh -i ~/.ssh/epicbook-key ubuntu@<YOUR_IP>
```

**Step 5.2: Check Application Service**

```bash
sudo systemctl status epicbook
```

Expected: `Active: active (running)`

**Step 5.3: Test Locally**

```bash
curl http://localhost:8080
```

**Step 5.4: Exit SSH**

```bash
exit
```

**Step 5.5: Access in Browser**

```bash
terraform output application_url
```

Open the URL in your browser. You should see the EpicBook homepage!

---

## Troubleshooting

### Issue 1: Service Failed

If `sudo systemctl status epicbook` shows "failed":

```bash
# Check logs
sudo journalctl -u epicbook -n 50

# Try running manually
cd /home/ubuntu/theepicbook
node server.js
```

Common cause: The app reads `config/config.json` instead of `.env`. 

**Fix:**
```bash
# Get RDS endpoint
exit  # Exit SSH
terraform output rds_address

# SSH back and create config.json
ssh -i ~/.ssh/epicbook-key ubuntu@<YOUR_IP>

cat > /home/ubuntu/theepicbook/config/config.json << EOF
{
  "development": {
    "username": "admin",
    "password": "YOUR_DB_PASSWORD",
    "database": "epicbookdb",
    "host": "YOUR_RDS_ENDPOINT",
    "dialect": "mysql"
  }
}
EOF

# Restart service
sudo systemctl restart epicbook
sudo systemctl status epicbook
```

### Issue 2: Can't Access Application

- Check security group allows port 80
- Verify instance is running
- Wait 5-10 minutes for user-data to complete

### Issue 3: Terraform Apply Fails

- Verify AWS credentials
- Check terraform.tfvars values
- Ensure password doesn't contain `/`, `@`, `"`, or spaces

---

## Clean Up Resources

**Important:** To avoid AWS charges:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This deletes all 14 resources.

**Cost after destroy:** $0

---

## What You Learned

### Technical Skills
- ✅ Writing Terraform configurations for AWS
- ✅ Designing VPC architecture
- ✅ Configuring security groups
- ✅ Deploying EC2 instances with automation
- ✅ Setting up RDS MySQL databases
- ✅ Configuring Nginx as reverse proxy
- ✅ Creating systemd services

### DevOps Concepts
- ✅ Infrastructure as Code (IaC)
- ✅ Declarative configuration
- ✅ Network isolation
- ✅ Security in depth
- ✅ Automated deployment

### AWS Services
- ✅ VPC, Subnets, Internet Gateways
- ✅ Security Groups
- ✅ EC2 instances
- ✅ Elastic IPs
- ✅ RDS MySQL

---

## Conclusion

Congratulations! You've successfully deployed a full-stack application on AWS using Terraform. This is a real DevOps skill that companies value.

**Next steps:**
- Add HTTPS with Let's Encrypt
- Enable RDS Multi-AZ
- Add CloudWatch monitoring
- Write a blog about your experience
- Add this to your portfolio

**Found this helpful?** Star the repository and share with others!

---

## Resources

- [GitHub Repository](https://github.com/GitHer-Muna/Full-Stack-Web-Application-Deployment-on-AWS-with-Terraform-IaC)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [TheEpicBook App](https://github.com/pravinmishraaws/theepicbook)

---

**Happy DevOps-ing! 🚀**

*If you found this tutorial helpful, please give it a clap and follow for more DevOps content!*
