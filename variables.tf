locals {
  # nuon dns
  enable_nuon_dns = contains(["1", "true"], var.enable_nuon_dns)
  nuon_dns = {
    enabled              = local.enable_nuon_dns
    internal_root_domain = var.internal_root_domain
    public_root_domain   = var.public_root_domain
  }

  # tags for all of the resources
  default_tags = merge(var.tags, {
    "install.nuon.co/id"      = var.nuon_id
    "sandbox.nuon.co/name"    = "aws-eks"
    "sandbox.nuon.co/variant" = "karpenter"
  })
  tags = merge(
    var.additional_tags,
    local.default_tags,
  )

  roles = {
    provision_iam_role_name   = split("/", var.provision_iam_role_arn)[length(split("/", var.provision_iam_role_arn)) - 1]
    deprovision_iam_role_name = split("/", var.deprovision_iam_role_arn)[length(split("/", var.deprovision_iam_role_arn)) - 1]
    maintenance_iam_role_name = split("/", var.maintenance_iam_role_arn)[length(split("/", var.maintenance_iam_role_arn)) - 1]
  }
}

#
# from cloudformation
#

variable "vpc_id" {
  type        = string
  description = "The ID of the AWS VPC to provision the sandbox in."
}

variable "maintenance_iam_role_arn" {
  type        = string
  description = "The provision IAM Role ARN"
}

variable "provision_iam_role_arn" {
  type        = string
  description = "The maintenance IAM Role ARN"
}

variable "deprovision_iam_role_arn" {
  type        = string
  description = "The deprovision IAM Role ARN"
}

#
# values from cloudformation install stack
#

# policies and roles
variable "provision_role_eks_kubernetes_groups" {
  type        = list(any)
  description = "List of Kubernetes Groups to add this role to. The provision role is assigned to a provision group automatically. These are additional groups."
  default     = []
}

variable "maintenance_role_eks_kubernetes_groups" {
  type        = list(any)
  description = "List of Kubernetes Groups to add this role to. The maintenance role is assigned to a maintenance group automatically. These are additional groups."
  default     = []
}

variable "deprovision_role_eks_kubernetes_groups" {
  type        = list(any)
  description = "List of Kubernetes Groups to add this role to. The deprovision role is assigned to a deprovision group automatically. These are additional groups."
  default     = []
}

#
# vendor defined via app config
#

variable "provision_role_eks_access_entry_policy_associations" {
  type        = map(any)
  description = "EKS Cluster Access Entry Policy Associations for provision role."
  default = {
    cluster_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
    eks_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
  }
}

variable "maintenance_role_eks_access_entry_policy_associations" {
  type        = map(any)
  description = "EKS Cluster Access Entry Policy Associations for maintenance role. Defaults to none meaning permissions are governed by eponymous RBAC group."
  default     = {}
  # default = {
  #   cluster_admin = {
  #     policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #     access_scope = {
  #       type = "cluster"
  #     }
  #   }
  #   eks_admin = {
  #     policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  #     access_scope = {
  #       type = "cluster"
  #     }
  #   }
  # }
}

variable "deprovision_role_eks_access_entry_policy_associations" {
  type        = map(any)
  description = "EKS Cluster Access Entry Policy Associations for deprovision role."
  default = {
    cluster_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
    eks_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
  }
}

variable "additional_access_entry" {
  type        = map(any)
  description = "A single access entry. Useful when providing access to an additional role."
  default     = {}
  # default = {
  #   "admin-access-for-org" = {
  #     principal_arn     = {{ admin_access_role }},
  #     kubernetes_groups = []
  #     policy_associations = {
  #       cluster_admin = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = {
  #           type = "cluster"
  #         }
  #       }
  #       eks_admin = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  #         access_scope = {
  #           type = "cluster"
  #         }
  #       }
  #     }
  #   }
  # }
}

# maintenance role RBAC
variable "maintenance_cluster_role_rules_override" {
  type = list(object({
    apiGroups     = list(string),
    resources     = list(string),
    verbs         = list(string),
    resourceNames = optional(list(string)),
  }))
  description = "A list of rules for the ClusterRole definition for the maintenance group. If this value is provided, these rules will be used instead."
  default     = []
}


variable "kyverno_policy_dir" {
  type        = string
  description = "Path to a directory with kyverno policy manifests."
  default     = "./kyverno-policies"
}

# additional IRSAs
variable "additional_irsas" {
  # name and serviceaccount are combined in oids.k8s.namespace_service_accounts as ["${var.namespace}:${serviceaccount}"]
  type = list(object({
    role_name       = string,
    namespace       = string,
    service_account = string,
  }))
  description = "List of additional IRSA accounts to create."
  default     = []
}

#
# install inputs
#

# cluster details
variable "cluster_version" {
  type        = string
  description = "The Kubernetes version to use for the EKS cluster."
  default     = "1.32"
}


variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster. If not provided, the install ID will be used by default."
  default     = ""
}

variable "min_size" {
  type        = number
  default     = 2
  description = "The minimum number of nodes in the managed node group."
}

variable "max_size" {
  type        = number
  default     = 5
  description = "The maximum number of nodes in the managed node group."
}

variable "desired_size" {
  type        = number
  default     = 3
  description = "The desired number of nodes in the managed node group."
}

variable "default_instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "The EC2 instance type to use for the EKS cluster's default node group."
}

variable "karpenter_replica_count" {
  type        = number
  default     = 2
  description = "The number of replicas for the Karpenter controller."
}

variable "karpenter_default_nodeclass_ami_selector_terms" {
  type        = any
  default     = null
  description = "If specified, override the included `default` nodeclass AMI selector terms."
}

variable "karpenter_default_nodepool_spec" {
  type        = any
  default     = null
  description = "If specified, override the included `default` nodepool spec."
}

variable "additional_tags" {
  type        = map(any)
  description = "Extra tags to append to the default tags that will be added to install resources."
  default     = {}
}

variable "additional_namespaces" {
  type        = list(string)
  description = "A list of namespaces that should be created on the cluster. The `{{.nuon.install.id}}` namespace is created by default."
  default     = []
}

variable "helm_driver" {
  type        = string
  description = "One of 'configmap' or 'secret'"
  default     = "secret"
}

#
# toggle-able components
#

# Nuon DNS
variable "enable_nuon_dns" {
  type        = string
  default     = "false"
  description = "Whether or not the cluster should use a nuon-provided nuon.run domain. Controls the cert-manager-issuer and the route_53_zone."
}

#
# set by nuon
#

variable "nuon_id" {
  type        = string
  description = "The nuon id for this install. Used for naming purposes."
}

variable "region" {
  type        = string
  description = "The region to launch the cluster in."
}

# DNS
variable "public_root_domain" {
  type        = string
  description = "The public root domain."
}

# NOTE: if you would like to create an internal load balancer, with TLS, you will have to use the public domain.
variable "internal_root_domain" {
  type        = string
  description = "The internal root domain."
}

variable "tags" {
  type        = map(any)
  description = "List of custom tags to add to the install resources. Used for taxonomic purposes."
}
