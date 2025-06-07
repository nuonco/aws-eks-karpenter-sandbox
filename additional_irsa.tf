module "additional_irsa" {
  for_each = {
    for index, ai in var.additional_irsas :
    ai.role_name => ai
  }
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = each.value.role_name
  attach_ebs_csi_policy = false

  oidc_providers = {
    k8s = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${each.value.namespace}:${each.value.service_account}"]
    }
  }

  tags = merge(local.tags, {
    "sandbox.nuon.co/module" = "additional_irsa"
    "sandbox.nuon.co/source" = "user-defined"
  })
  depends_on = [module.eks]
}
