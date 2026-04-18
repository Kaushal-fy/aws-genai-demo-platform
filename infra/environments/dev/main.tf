module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"
 
  name = "$(var.project_name)-vpc"
  cidr = "10.0.0.0/16"

  azs = ["ap-south-1a"]
  public_subnet = ["10.0.0.0/24"]

  enable_dns_hostname = true
  enable_dns_support = true

  enable_nat_gateway = false
  single_nat_gateway = false

  tags = {
    Project = var.project_name
    Name = "Kaush-vpc"
  }

}

