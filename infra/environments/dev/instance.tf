resource "aws_instance" "demo" {
  ami           = "ami-0f5ee92e2d63afc18" # Amazon Linux 2 (update if needed)
  instance_type = "t3.micro"

  subnet_id = module.vpc.public_subnets[0]

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3
              echo "Hello from EC2" > index.html
              python3 -m http.server 80 &
              EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
