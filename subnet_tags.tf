module "additional_subnet_tags" {
  # only create if the cluster name does not equal the nuon id
  count = module.eks.cluster_name == var.nuon_id ? 0 : 1

  source = "./subnet_tags"

  eks_cluster_name   = module.eks.cluster_name
  private_subnet_ids = local.subnets.private.ids
  public_subnet_ids  = local.subnets.public.ids
  depends_on         = [module.eks]
}

// add karpenter tags
resource "aws_ec2_tag" "private_subnets_karpenter_tags" {
  for_each    = toset(local.subnets.private.ids)
  resource_id = each.value
  key         = local.karpenter.discovery_key
  value       = local.karpenter.discovery_value
}
