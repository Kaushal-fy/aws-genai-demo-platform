resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    tags = {Name = "main-vpc"}
    }

resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.main.id
    tags = {Name = "main-igw"}
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.pub_subnet_cidr
    map_public_ip_on_launch = true
    tags = {Name = "public_subnet"}
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id
    route {
      cidr_block = "0.0.0.0"
      gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "public_rt_assc" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public_rt.id
}
