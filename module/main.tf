module "nuon-aws-eks-sandbox" {
  source = "./.."

  vpc_id                   = var.vpc_id
  provision_iam_role_arn   = var.provision_iam_role_arn
  maintenance_iam_role_arn = var.maintenance_iam_role_arn
  deprovision_iam_role_arn = var.deprovision_iam_role_arn

  provision_role_eks_access_entry_policy_associations   = var.provision_role_eks_access_entry_policy_associations
  maintenance_role_eks_access_entry_policy_associations = var.maintenance_role_eks_access_entry_policy_associations
  deprovision_role_eks_access_entry_policy_associations = var.deprovision_role_eks_access_entry_policy_associations

  additional_access_entry = var.additional_access_entry
  additional_namespaces   = var.additional_namespaces

  maintenance_cluster_role_rules_override = var.maintenance_cluster_role_rules_override

  kyverno_policy_dir = var.kyverno_policy_dir

  # cluster
  cluster_version       = var.cluster_version
  cluster_name          = var.cluster_name
  min_size              = var.min_size
  max_size              = var.max_size
  desired_size          = var.desired_size
  default_instance_type = var.default_instance_type

  # toggleable components
  enable_nuon_dns = var.enable_nuon_dns

  # provided by nuon
  nuon_id              = var.nuon_id
  internal_root_domain = var.internal_root_domain
  public_root_domain   = var.public_root_domain
  region               = var.region
  tags                 = var.tags
}
