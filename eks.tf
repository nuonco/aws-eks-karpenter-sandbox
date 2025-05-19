locals {
  cluster_name    = substr((var.cluster_name != "" ? var.cluster_name : var.nuon_id), 0, 38)
  cluster_version = var.cluster_version

  instance_types = [var.default_instance_type]
  min_size       = var.min_size
  max_size       = var.max_size
  desired_size   = var.desired_size

  // access entries
  // three roles in play: provision, deprovision, maintenance
  // this becomes the provision role
  default_access_entries = {
    "provision" = {
      principal_arn       = var.provision_iam_role_arn
      kubernetes_groups   = concat(["provision"], var.provision_role_eks_kubernetes_groups)
      policy_associations = var.provision_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
    "maintenance" = {
      principal_arn       = var.maintenance_iam_role_arn
      kubernetes_groups   = concat(["maintenance"], var.maintenance_role_eks_kubernetes_groups)
      policy_associations = var.maintenance_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
    "deprovision" = {
      principal_arn       = var.deprovision_iam_role_arn
      kubernetes_groups   = concat(["deprovision"], var.deprovision_role_eks_kubernetes_groups)
      policy_associations = var.deprovision_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
  }

  access_entries = merge(local.default_access_entries, var.additional_access_entry)
}

resource "aws_kms_key" "eks" {
  description = "Key for ${local.cluster_name} EKS cluster"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.35.0"

  cluster_name                    = local.cluster_name
  cluster_version                 = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = data.aws_vpc.vpc.id
  subnet_ids = local.subnets.private.ids

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  cluster_addons = {
    coredns = {
      configuration_values = jsonencode({
        tolerations = [
          # Allow CoreDNS to run on the same nodes as the Karpenter controller
          # for use during cluster creation when Karpenter nodes do not yet exist
          #
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
      })
    }
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      most_recent = true
      preserve    = true
    }
  }

  authentication_mode                      = "API_AND_CONFIG_MAP"
  access_entries                           = local.access_entries
  enable_cluster_creator_admin_permissions = false
  eks_managed_node_groups = {
    karpenter = {
      instance_types = local.instance_types
      min_size       = local.min_size
      max_size       = local.max_size
      desired_size   = local.desired_size

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

      iam_role_additional_policies = {
        additional = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  node_security_group_tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.cluster_name}" = null
    "karpenter.sh/discovery"                      = local.karpenter.discovery_value
  })

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.karpenter.discovery_value
  })
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
