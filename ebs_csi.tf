locals {
  ebs_csi = {
    name      = "ebs-csi-controller"
    namespace = "ebs-csi-controller"
  }
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.0"

  role_name             = "ebs-csi-${var.nuon_id}"
  attach_ebs_csi_policy = true

  oidc_providers = {
    k8s = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.ebs_csi.name}:${local.ebs_csi.name}-sa"]
    }
  }

  tags = local.tags
}

resource "helm_release" "ebs_csi" {
  namespace        = local.ebs_csi.namespace
  create_namespace = true

  name       = local.ebs_csi.name
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.16.0"

  provider = helm.main

  values = [
    yamlencode({
      node : {
        tolerateAllTaints : true
      }
      controller : {
        k8sTagClusterId : module.eks.cluster_name
        serviceAccount : {
          annotations : {
            "eks.amazonaws.com/role-arn" : module.ebs_csi_irsa.iam_role_arn
          }
        }
        tolerations : [
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
    }),
  ]


  depends_on = [
    module.ebs_csi_irsa,
    module.eks,
    resource.aws_security_group_rule.runner_cluster_access,
  ]
}
