

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${local.mytag}-vpc"
    Project = local.mytag
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "main-igw"
    Project = local.mytag
  }
}

# Public Subnets - One in each AZ
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "public-subnet-${var.availability_zones[count.index]}"
    Project = local.mytag
  }
}

# Private Subnets - One in each AZ
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "private-subnet-${var.availability_zones[count.index]}"
    Project = local.mytag
  }
}

# NAT Gateway Elastic IPs - One for each AZ
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name    = "nat-eip-${var.availability_zones[count.index]}"
    Project = local.mytag
  }
}

# NAT Gateways - One in each AZ's public subnet
resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name    = "nat-gateway-${var.availability_zones[count.index]}"
    Project = local.mytag
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "public-rt"
    Project = local.mytag
  }
}

# Private Route Tables - One for each AZ
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name    = "private-rt-${var.availability_zones[count.index]}"
    Project = local.mytag
  }
}

# Route Table Associations - Public
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations - Private
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group
resource "aws_security_group" "web_sg" {
  name        = "${local.mytag}-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "${local.mytag}-sg"
    Project = local.mytag
  }
}

# Key Pair
resource "aws_key_pair" "awskey" {
  key_name   = "awskey"
  public_key = file(var.public_key_path)
}

# EC2 Instances in Public Subnets - One in each AZ
resource "aws_instance" "public_instance" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.awskey.key_name
  user_data              = file("${path.module}/kubeadm.sh")

  tags = {
    Name    = "public-instance-${var.availability_zones[count.index]}"
    Project = local.mytag
  }
}

# EC2 Instances in Private Subnets - One in each AZ
resource "aws_instance" "private_instance" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.awskey.key_name
  user_data              = file("${path.module}/kubeadm.sh")

  tags = {
    Name    = "private-instance-${var.availability_zones[count.index]}"
    Project = local.mytag
  }
}

# Output
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_instance_ips" {
  value = aws_instance.public_instance[*].public_ip
}

output "private_instance_ips" {
  value = aws_instance.private_instance[*].private_ip
}