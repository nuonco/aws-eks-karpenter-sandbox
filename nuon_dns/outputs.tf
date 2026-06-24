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
    enabled = var.enable_external_dns
    release = var.enable_external_dns ? {
      id        = helm_release.external_dns[0].id
      namespace = helm_release.external_dns[0].metadata[0].namespace
      name      = helm_release.external_dns[0].metadata[0].name
      chart     = helm_release.external_dns[0].metadata[0].chart
      revision  = helm_release.external_dns[0].metadata[0].revision
      } : {
      id        = ""
      namespace = ""
      name      = ""
      chart     = ""
      revision  = ""
    }
  }
}

output "cert_manager" {
  value = {
    enabled = var.enable_cert_manager
    release = var.enable_cert_manager ? {
      id        = helm_release.cert_manager[0].id
      namespace = helm_release.cert_manager[0].metadata[0].namespace
      name      = helm_release.cert_manager[0].metadata[0].name
      chart     = helm_release.cert_manager[0].metadata[0].chart
      revision  = helm_release.cert_manager[0].metadata[0].revision
      } : {
      id        = ""
      namespace = ""
      name      = ""
      chart     = ""
      revision  = ""
    }
  }
}

output "ingress_nginx" {
  value = {
    enabled = var.enable_ingress_nginx
    release = var.enable_ingress_nginx ? {
      id        = helm_release.ingress_nginx[0].id
      namespace = helm_release.ingress_nginx[0].metadata[0].namespace
      name      = helm_release.ingress_nginx[0].metadata[0].name
      chart     = helm_release.ingress_nginx[0].metadata[0].chart
      revision  = helm_release.ingress_nginx[0].metadata[0].revision
      } : {
      id        = ""
      namespace = ""
      name      = ""
      chart     = ""
      revision  = ""
    }
  }
}

output "alb_ingress_controller" {
  value = {
    enabled = var.enable_alb_ingress_controller
    release = var.enable_alb_ingress_controller ? {
      id        = helm_release.alb_ingress_controller[0].id
      namespace = helm_release.alb_ingress_controller[0].metadata[0].namespace
      name      = helm_release.alb_ingress_controller[0].metadata[0].name
      chart     = helm_release.alb_ingress_controller[0].metadata[0].chart
      revision  = helm_release.alb_ingress_controller[0].metadata[0].revision
      } : {
      id        = ""
      namespace = ""
      name      = ""
      chart     = ""
      revision  = ""
    }
  }
}
