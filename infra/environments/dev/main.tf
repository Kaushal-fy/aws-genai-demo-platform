module "vpc" {
  source = "../../modules/vpc"

  cidr_block         = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  availability_zone  = "ap-south-1a"
}

module "ec2" {
  source = "../../modules/ec2"

  ami           = "ami-xxxxxxxx"
  instance_type = "t2.micro"
  subnet_id     = module.vpc.subnet_id
  vpc_id        = module.vpc.vpc_id
  key_name      = "your-key"
}
