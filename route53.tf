data "aws_route53_zone" "public" {
  name         = var.public_subdomain
  private_zone = false
}