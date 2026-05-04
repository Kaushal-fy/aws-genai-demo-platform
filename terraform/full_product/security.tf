resource "aws_security_group" "worker" {
  name        = "${local.name_prefix}-worker-sg"
  description = "Egress-only security group for ECS worker tasks."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-worker-sg"
  }
}