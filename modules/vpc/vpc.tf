# VPC
resource "aws_vpc" "myvpc" {
  cidr_block = local.vpc_cidr

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

