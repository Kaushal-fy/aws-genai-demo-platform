########################################
# IAM ROLE FOR SSM
########################################

resource "aws_iam_role" "ec2_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

########################################
# ATTACH SSM POLICY
########################################

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

########################################
# INSTANCE PROFILE
########################################

resource "aws_iam_instance_profile" "profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

########################################
# EC2 INSTANCE
########################################

resource "aws_instance" "demo" {
  ami           = var.ami
  instance_type = var.instance_type

  subnet_id = module.vpc.public_subnets[0]

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3
              echo "Hello from EC2" > index.html
              nohup python3 -m http.server 80 &
              EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
