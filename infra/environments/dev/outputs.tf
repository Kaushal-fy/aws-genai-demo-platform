output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet" {
  value = module.vpc.public_subnets[0]
}

output "ec2_public_ip" {
  value = aws_instance.demo.public_ip
}
