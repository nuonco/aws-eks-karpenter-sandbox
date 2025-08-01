output "account" {
  value = {
    id     = data.aws_caller_identity.current.account_id
    region = var.region
  }
  description = "A map of AWS account attributes: id, region."
}

output "cluster" {
  // NOTE: these are declared here -
  // https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest?tab=outputs
  value = {
    arn                        = module.eks.cluster_arn
    certificate_authority_data = module.eks.cluster_certificate_authority_data
    endpoint                   = module.eks.cluster_endpoint
    name                       = module.eks.cluster_name
    platform_version           = module.eks.cluster_platform_version
    status                     = module.eks.cluster_status
    oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
    oidc_provider_arn          = module.eks.oidc_provider_arn
    oidc_provider              = module.eks.oidc_provider

    cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
    cluster_security_group_id         = module.eks.cluster_security_group_id

    node_security_group_id = module.eks.node_security_group_id
    node_groups            = module.eks.eks_managed_node_groups
  }
  description = "A map of EKS cluster attributes: arn, certificate_authority_data, endpoint, name, platform_version, status, oidc_issuer_url, oidc_provider_arn, cluster_security_group_id, node_security_group_id."
}

output "vpc" {
  value = {
    // NOTE: these are declared here -
    // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
    id   = data.aws_vpc.vpc.id
    arn  = data.aws_vpc.vpc.arn
    cidr = data.aws_vpc.vpc.cidr_block
    azs  = data.aws_availability_zones.available.names
    # replaces this next line - overall not necessary
    # azs  = data.aws_vpc.vpc.azs

    // ensure the data resource will actually hand us this
    private_subnet_cidr_blocks = local.subnets.private.cidrs
    private_subnet_ids         = local.subnets.private.ids

    public_subnet_cidr_blocks = local.subnets.public.cidrs
    public_subnet_ids         = local.subnets.public.ids
    runner_subnet_id          = local.subnets.runner.ids[0]
    runner_subnet_cidr        = local.subnets.runner.cidrs[0]

    default_security_group_id = data.aws_security_group.default.id
  }
  description = "A map of vpc attributes: name, id, cidr, azs, private_subnet_cidr_blocks, private_subnet_ids, public_subnet_cidr_blocks, public_subnet_ids, default_security_group_id."
}

output "ecr" {
  value = {
    repository_url  = module.ecr.repository_url
    repository_arn  = module.ecr.repository_arn
    repository_name = var.nuon_id
    registry_id     = module.ecr.repository_registry_id
    registry_url    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  }
  description = "A map of ECR attributes: repository_url, repository_arn, repository_name, registry_id, registry_url."
}


output "nuon_dns" {
  value = {
    enabled         = local.nuon_dns.enabled,
    public_domain   = local.nuon_dns.enabled ? module.nuon_dns[0].public_domain : { zone_id : "", name : "", nameservers : tolist([""]) }
    internal_domain = local.nuon_dns.enabled ? module.nuon_dns[0].internal_domain : { zone_id : "", name : "", nameservers : tolist([""]) }
    alb_ingress_controller = {
      enabled  = local.nuon_dns.enabled
      id       = local.nuon_dns.enabled ? module.nuon_dns[0].alb_ingress_controller.release.id : ""
      chart    = local.nuon_dns.enabled ? module.nuon_dns[0].alb_ingress_controller.release.chart : ""
      revision = local.nuon_dns.enabled ? module.nuon_dns[0].alb_ingress_controller.release.revision : ""
    }
    external_dns = {
      enabled  = local.nuon_dns.enabled
      id       = local.nuon_dns.enabled ? module.nuon_dns[0].external_dns.release.id : ""
      chart    = local.nuon_dns.enabled ? module.nuon_dns[0].external_dns.release.chart : ""
      revision = local.nuon_dns.enabled ? module.nuon_dns[0].external_dns.release.revision : ""
    }
    cert_manager = {
      enabled  = local.nuon_dns.enabled
      id       = local.nuon_dns.enabled ? module.nuon_dns[0].cert_manager.release.id : ""
      chart    = local.nuon_dns.enabled ? module.nuon_dns[0].cert_manager.release.chart : ""
      revision = local.nuon_dns.enabled ? module.nuon_dns[0].cert_manager.release.revision : ""
    }
    ingress_nginx = {
      enabled  = local.nuon_dns.enabled
      id       = local.nuon_dns.enabled ? module.nuon_dns[0].ingress_nginx.release.id : ""
      chart    = local.nuon_dns.enabled ? module.nuon_dns[0].ingress_nginx.release.chart : ""
      revision = local.nuon_dns.enabled ? module.nuon_dns[0].ingress_nginx.release.revision : ""
    }
  }
  description = "A map of Nuon DNS attributes: whether nuon.run has been enabled; AWS Route 53 details for the public_domain and internal_domain; metadata bout the helm charts the module installs on."
}

output "namespaces" {
  value       = [for km in kubectl_manifest.namespaces : km.name]
  description = "A list of namespaces that were created by this module."
}

output "karpenter" {
  value = {
    instance_profile = {
      id   = resource.aws_iam_instance_profile.karpenter.id
      arn  = resource.aws_iam_instance_profile.karpenter.arn
      name = local.karpenter.instance_profile_name
    }
    discovery_key   = local.karpenter.discovery_key
    discovery_value = local.karpenter.discovery_value

  }
}

output "additional_irsa" {
  value = { for ai in module.additional_irsa : ai.iam_role_name => ai }
}
