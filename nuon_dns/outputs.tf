output "public_domain" {
  value = {
    nameservers = aws_route53_zone.public.name_servers
    name        = aws_route53_zone.public.name
    zone_id     = aws_route53_zone.public.id
  }
}

output "internal_domain" {
  value = {
    nameservers = aws_route53_zone.internal.name_servers
    name        = aws_route53_zone.internal.name
    zone_id     = aws_route53_zone.internal.id
  }
}

output "external_dns" {
  value = {
    enabled = true
    release = {
      id        = helm_release.external_dns.id
      namespace = helm_release.external_dns.metadata[0].namespace
      name      = helm_release.external_dns.metadata[0].name
      chart     = helm_release.external_dns.metadata[0].chart
      revision  = helm_release.external_dns.metadata[0].revision
    }
  }
}

output "cert_manager" {
  value = {
    enabled = true
    release = {
      id        = helm_release.cert_manager.id
      namespace = helm_release.cert_manager.metadata[0].namespace
      name      = helm_release.cert_manager.metadata[0].name
      chart     = helm_release.cert_manager.metadata[0].chart
      revision  = helm_release.cert_manager.metadata[0].revision
    }
  }
}

output "ingress_nginx" {
  value = {
    enabled = true
    release = {
      id        = helm_release.ingress_nginx.id
      namespace = helm_release.ingress_nginx.metadata[0].namespace
      name      = helm_release.ingress_nginx.metadata[0].name
      chart     = helm_release.ingress_nginx.metadata[0].chart
      revision  = helm_release.ingress_nginx.metadata[0].revision
    }
  }
}

output "alb_ingress_controller" {
  value = {
    enabled = true
    release = {
      id        = helm_release.alb_ingress_controller.id
      namespace = helm_release.alb_ingress_controller.metadata[0].namespace
      name      = helm_release.alb_ingress_controller.metadata[0].name
      chart     = helm_release.alb_ingress_controller.metadata[0].chart
      revision  = helm_release.alb_ingress_controller.metadata[0].revision
    }
  }
}
