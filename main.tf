module "vpc" {
  source = "./modules/vpc"

  availability_zones  = local.availability_zones
  public_subnet_cidrs = local.public_subnet_cidrs
}