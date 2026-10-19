locals {
  cluster_name    = substr((var.cluster_name != "" ? var.cluster_name : var.nuon_id), 0, 38)
  cluster_version = var.cluster_version

  instance_types = [var.default_instance_type]
  ami_type       = var.ami_type
  min_size       = var.min_size
  max_size       = var.max_size
  desired_size   = var.desired_size

  node_group_ami_release_version = var.node_group_ami_release_version

  // access entries
  // three roles in play: provision, deprovision, maintenance
  // provision and deprovision are conditionally created based on whether their ARNs are provided
  default_access_entries = {
    "maintenance" = {
      principal_arn       = var.maintenance_iam_role_arn
      kubernetes_groups   = concat(["maintenance"], var.maintenance_role_eks_kubernetes_groups)
      policy_associations = var.maintenance_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
  }

  provision_access_entry = var.provision_iam_role_arn != "" ? {
    "provision" = {
      principal_arn       = var.provision_iam_role_arn
      kubernetes_groups   = concat(["provision"], var.provision_role_eks_kubernetes_groups)
      policy_associations = var.provision_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
  } : {}

  deprovision_access_entry = var.deprovision_iam_role_arn != "" ? {
    "deprovision" = {
      principal_arn       = var.deprovision_iam_role_arn
      kubernetes_groups   = concat(["deprovision"], var.deprovision_role_eks_kubernetes_groups)
      policy_associations = var.deprovision_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
  } : {}

  break_glass_access_entry = var.break_glass_iam_role_arn != "" ? {
    "break_glass" = {
      principal_arn       = var.break_glass_iam_role_arn
      kubernetes_groups   = concat(["break_glass"], var.break_glass_role_eks_kubernetes_groups)
      policy_associations = var.break_glass_role_eks_access_entry_policy_associations,
      tags                = local.tags
    }
  } : {}

  access_entries = merge(local.default_access_entries, local.provision_access_entry, local.deprovision_access_entry, local.break_glass_access_entry, var.additional_access_entry)

  default_cluster_addons = {
    coredns = {
      configuration_values = {
        tolerations = [
          # Allow CoreDNS to run on the same nodes as the Karpenter controller
          # for use during cluster creation when Karpenter nodes do not yet exist
          {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NoSchedule"
          },
          {
            key    = "CriticalAddonsOnly"
            value  = "true"
            effect = "NoSchedule"
          },
        ]
      }
    }
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      most_recent = true
      preserve    = true
    }
  }

  # null entries in var.cluster_addons remove a default; everything else overrides/extends.
  # configuration_values may be passed as an object — we jsonencode it here since the AWS
  # provider requires a string.
  cluster_addons_encoded = {
    for k, v in merge(local.default_cluster_addons, var.cluster_addons) :
    k => merge(v, lookup(v, "configuration_values", null) == null ? {} : {
      configuration_values = try(tostring(v.configuration_values), jsonencode(v.configuration_values))
    }) if v != null
  }

  # CoreDNS addon defaults to compute-type=ec2; switch to Fargate unless the caller set one.
  coredns_configuration_object = try(jsondecode(local.cluster_addons_encoded.coredns.configuration_values), null)
  coredns_compute_type_set = (
    try(local.coredns_configuration_object.computeType, null) != null ||
    try(local.coredns_configuration_object.podAnnotations["eks.amazonaws.com/compute-type"], null) != null
  )

  cluster_addons = {
    for k, v in local.cluster_addons_encoded : k => (
      var.karpenter_on_fargate && k == "coredns" && !local.coredns_compute_type_set ? merge(v, {
        configuration_values = jsonencode(merge(coalesce(local.coredns_configuration_object, {}), {
          computeType = "Fargate"
        }))
      }) : v
    )
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name                           = local.cluster_name
  cluster_version                        = local.cluster_version
  cluster_endpoint_private_access        = true
  cluster_endpoint_public_access         = var.cluster_endpoint_public_access
  cluster_enabled_log_types              = var.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days

  vpc_id     = data.aws_vpc.vpc.id
  subnet_ids = local.subnets.private.ids

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = local.cluster_kms_key_arn
    resources        = ["secrets"]
  }

  cloudwatch_log_group_kms_key_id = local.cloudwatch_logs_kms_key_arn

  cluster_addons = local.cluster_addons

  authentication_mode                      = "API_AND_CONFIG_MAP"
  access_entries                           = local.access_entries
  enable_cluster_creator_admin_permissions = false
  eks_managed_node_groups = var.karpenter_on_fargate ? {} : {
    karpenter = {
      instance_types = local.instance_types
      ami_type       = local.ami_type
      min_size       = local.min_size
      max_size       = local.max_size
      desired_size   = local.desired_size

      use_latest_ami_release_version = local.node_group_ami_release_version == "latest"
      ami_release_version            = contains(["", "latest"], local.node_group_ami_release_version) ? null : local.node_group_ami_release_version

      # Used to ensure Karpenter runs on nodes that it does not manage
      labels = {
        "karpenter.sh/controller" = "true"
      }
      # won't schedule on nodes it manages
      taints = {
        karpenter = {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
      tags = {
        "karpenter.sh/discovery" = local.karpenter.discovery_value
      }

      create_iam_role = false
      iam_role_arn    = aws_iam_role.karpenter_node[0].arn
    }
  }
  fargate_profiles = var.karpenter_on_fargate ? {
    karpenter = {
      subnet_ids = local.subnets.private.ids
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "app.kubernetes.io/name" = "karpenter"
          }
        },
        # controller uses ClusterFirst DNS before any Karpenter node exists
        {
          namespace = "kube-system"
          labels = {
            "k8s-app" = "kube-dns"
          }
        },
      ]
    }
  } : {}

  node_security_group_tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.cluster_name}" = null
    "karpenter.sh/discovery"                      = local.karpenter.discovery_value
  })

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.karpenter.discovery_value
  })

  depends_on = [aws_iam_role_policy_attachment.karpenter_node]
}

# TODO: revisit this access method
resource "aws_security_group_rule" "runner_cluster_access" {
  type                     = "ingress"
  description              = "Allow ingress traffic from runner."
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = data.aws_security_groups.runner.ids[0] # make this less brittle

  depends_on = [module.eks]
}
