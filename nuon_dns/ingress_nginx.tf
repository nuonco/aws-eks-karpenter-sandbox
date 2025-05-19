locals {
  ingress_nginx = {
    namespace = "ingress-nginx"
    name      = "ingress-nginx"
    tolerations = [
      {
        key    = "karpenter.sh/controller"
        value  = "true"
        effect = "NoSchedule"
      },
      {
        key : "CriticalAddonsOnly"
        value : "true"
        effect : "NoSchedule"
      },
    ]
  }
}

resource "helm_release" "ingress_nginx" {
  namespace        = local.ingress_nginx.namespace
  create_namespace = true

  name       = local.ingress_nginx.name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.1"
  timeout    = 600

  set {
    name  = "rbac.create"
    value = "true"
  }

  values = [
    yamlencode({
      tolerations = local.ingress_nginx.tolerations
      controller = {
        tolerations = local.ingress_nginx.tolerations
        admissionWebhooks = {
          patch = {
            tolerations = local.ingress_nginx.tolerations
          }
        }
      }
    })
  ]

  depends_on = [
    helm_release.alb_ingress_controller
  ]
}
