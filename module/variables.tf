# provision_iam_role_arn
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
# from configs
#

# docs: https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html

# policies and roles
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
  description = "EKS Cluster Access Entry Policy Associations for maintenance role."
  default = {
    # cluster_admin = {
    #   policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    #   access_scope = {
    #     type = "cluster"
    #   }
    # }
    # eks_admin = {
    #   policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
    #   access_scope = {
    #     type = "cluster"
    #   }
    # }
    # eks_view = {
    #   policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
    #   access_scope = {
    #     type = "cluster"
    #   }
    # }
  }
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
  #   "developer-admin-access" = {
  #     principal_arn     = "arn:aws:iam::949309607565:role/AWSReservedSSO_NuonAdmin_c8da2fb36eb453b5"
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
    apiGroups = list(string),
    resources = list(string),
    verbs     = list(string)
  }))
  description = "A list of rules for the ClusterRole definition for the maintenance group. If this value is provided, these rules will be used instead."
  default     = []
}


variable "kyverno_policy_dir" {
  type        = string
  description = "Path to a directory with kyverno policy manifests."
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

#
# toggle-able components
#

# Nuon DNS
variable "enable_nuon_dns" {
  type        = string
  default     = "false"
  description = "Whether or not the cluster should use a nuon-provided nuon.run domain. Controls the cert-manager-issuer and the route_53_zone."
}

# toggle-able helm charts
# TODO

#
# set by nuon
#
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
