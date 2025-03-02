# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnet_cidrs)
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${element(var.availability_zones, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}

# Internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name"        = "${var.environment}-igw"
    "Environment" = var.environment
  }
}


# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}


# Route table associations for both Public subnet and Private subnet
resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

# Create security group
resource "aws_security_group" "arslan_sg" {
  name        = "arslan-sg"
  description = "arslan-sg"
  vpc_id      = aws_vpc.vpc.id # Replace with your VPC ID or resource

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # all protocols
    cidr_blocks = ["0.0.0.0/0"] # all IPs
    description = "Allow all inbound traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # all protocols
    cidr_blocks = ["0.0.0.0/0"] # all IPs
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "allow-all-inbound"
  }
}


# Create a keypair
resource "aws_key_pair" "awskey" {
  key_name   = "awskey"
  public_key = file("~/.ssh/id_ed25519.pub") # Replace with your public key path
}

# Create ec2 instance
resource "aws_instance" "controlplane" {
  ami           = "ami-04b4f1a9cf54c11d0" # Replace with a valid AMI ID
  instance_type = "t3.medium"
  key_name      = aws_key_pair.awskey.key_name
  subnet_id     = aws_subnet.public_subnet[0].id #replace with your subnet id
  vpc_security_group_ids = [aws_security_group.arslan_sg.id] #replace with your security group id

   root_block_device {
    volume_size = 12 # Set root volume to 12GB
  }

  tags = {
    Name = "ec2-instance"
  }
}