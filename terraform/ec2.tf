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
