locals {
  cert_manager = {
    name      = "cert-manager"
    namespace = "cert-manager"
  }
}

module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "cert-manager-${var.nuon_id}"

  attach_cert_manager_policy = true
  cert_manager_hosted_zone_arns = [
    aws_route53_zone.internal.arn,
    aws_route53_zone.public.arn,
  ]

  oidc_providers = {
    k8s = {
      provider_arn               = var.eks_oidc_provider_arn
      namespace_service_accounts = ["${local.cert_manager.namespace}:${local.cert_manager.name}"]
    }
  }

  tags = var.tags
}

resource "helm_release" "cert_manager" {
  namespace        = local.cert_manager.namespace
  create_namespace = true

  name       = local.cert_manager.name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.11.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cert_manager_irsa.iam_role_arn
  }

  set {
    name  = "securityContext.fsGroup"
    value = "1001"
  }

  # toleration require to allow these to run on the main karpenter mng ng
  values = [
    yamlencode({
      tolerations = [
        {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NoSchedule"
        },
        {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NoSchedule"
        },
      ]
      webhook = {
        tolerations = [
          {
            key    = "CriticalAddonsOnly"
            value  = "true"
            effect = "NoSchedule"
          },
          {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NoSchedule"
          },
        ]
      }
      cainjector = {
        tolerations = [
          {
            key    = "CriticalAddonsOnly"
            value  = "true"
            effect = "NoSchedule"
          },
          {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NoSchedule"
          },
        ]
      }
      startupapicheck = {
        tolerations = [
          {
            key    = "CriticalAddonsOnly"
            value  = "true"
            effect = "NoSchedule"
          },
          {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NoSchedule"
          },
        ]
      }
    }),
  ]

  depends_on = [
    module.cert_manager_irsa,
  ]
}
