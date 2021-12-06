module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "2.12.0"

  create_certificate = true
  domain_name        = var.public_subdomain
  zone_id            = data.aws_route53_zone.public.zone_id
  subject_alternative_names = [
    "ecs.${var.public_subdomain}",
    "*.ecs.${var.public_subdomain}"
  ]
}

output "aws_caller_identity" {
  value = data.aws_caller_identity.current
}
