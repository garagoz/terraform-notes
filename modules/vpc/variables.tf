variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "arslan"
}

variable "availability_zones" {
  description = "AZs for Subnets"
  type = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for Public Subnet"
  type = list(string)
}