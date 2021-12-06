resource "aws_default_vpc" "default" {}

data "aws_subnet_ids" "default_subtets" {
  vpc_id = aws_default_vpc.default.id
}

data "aws_security_group" "default" {
  vpc_id = aws_default_vpc.default.id
  name   = "default"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "alb_sg" {
  name   = "${var.prefix}-alb_sg"
  vpc_id = aws_default_vpc.default.id

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}