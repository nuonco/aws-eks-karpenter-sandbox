locals {
  alb_ingress_controller = {
    namespace            = "alb-ingress-controller"
    service_account_name = "alb-ingress-controller"
  }
}

module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "alb-controller-${var.nuon_id}"

  create_role                            = true
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    k8s = {
      provider_arn               = var.eks_oidc_provider_arn
      namespace_service_accounts = ["${local.alb_ingress_controller.namespace}:${local.alb_ingress_controller.service_account_name}"]
    }
  }

  tags = var.tags
}

resource "helm_release" "alb_ingress_controller" {
  namespace        = local.alb_ingress_controller.namespace
  create_namespace = true

  name       = "alb-ingress-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.12.0"

  set {
    name  = "enableCertManager"
    value = "apply"
  }

  set {
    name  = "clusterName"
    value = var.eks_cluster_name
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = local.alb_ingress_controller.service_account_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa.iam_role_arn
  }

  set { // we only set this one tag in case any of the others (in local.tags) conflict.
    name  = "defaultTags.nuon_install_id"
    value = var.nuon_id
  }

  set {
    name  = "defaultTags.install\\.nuon\\.co\\/id"
    value = var.nuon_id
  }

  set { // we only set this one tag in case any of the others (in local.tags) conflict.
    name  = "defaultTags.created_by"
    value = "alb-ingress-controller"
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
    })
  ]

  depends_on = [
    helm_release.cert_manager,
    module.alb_controller_irsa,
  ]
}
