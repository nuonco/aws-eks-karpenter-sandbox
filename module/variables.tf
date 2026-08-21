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
  description = "The provision IAM Role ARN. If empty, no EKS access entry will be created for this role."
  default     = ""
}

variable "deprovision_iam_role_arn" {
  type        = string
  description = "The deprovision IAM Role ARN. If empty, no EKS access entry will be created for this role."
  default     = ""
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

variable "cluster_enabled_log_types" {
  type        = list(string)
  description = "EKS control-plane log types to send to CloudWatch. All enabled types share /aws/eks/<cluster>/cluster; retention is cloudwatch_log_group_retention_in_days."
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition = alltrue([
      for t in var.cluster_enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], t)
    ])
    error_message = "cluster_enabled_log_types values must be api, audit, authenticator, controllerManager, or scheduler."
  }
}

variable "cloudwatch_log_group_retention_in_days" {
  type        = number
  description = "Number of days to retain EKS control-plane logs in CloudWatch."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_log_group_retention_in_days)
    error_message = "cloudwatch_log_group_retention_in_days must be 0 (never expire) or a retention period supported by CloudWatch Logs."
  }
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

variable "ami_type" {
  type        = string
  default     = "AL2023_x86_64_STANDARD"
  description = "The AMI type for the EKS cluster's default node group. Use an ARM_64 variant (e.g. AL2023_ARM_64_STANDARD) to run the node group on Graviton instances."
}

variable "cluster_encryption_kms_key_id" {
  type        = string
  description = "An existing KMS key (CMK) to use for EKS secrets encryption, given as a key ID, key ARN, alias name, or alias ARN. The key must live in the same region as the cluster and its key policy must allow the cluster IAM role to use it. If empty, this module creates a key."
  default     = ""
}

variable "ebs_encryption_kms_key_id" {
  type        = string
  description = "An existing KMS key (CMK) to use for EBS encryption, given as a key ID, key ARN, alias name, or alias ARN. This grants the EBS CSI driver and the Karpenter controller permission to use the key; the key policy must allow those roles in turn (see the `karpenter.controller_iam_role` output). Dynamically provisioned PersistentVolumes are encrypted with it. Karpenter node root volumes are not - to encrypt those, also set `kmsKeyID` to this key in `var.karpenter_default_nodeclass_block_device_mappings`. If empty, no KMS permissions are granted and EBS encryption is left at the account default."
  default     = ""
}

variable "ecr_encryption_kms_key_id" {
  type        = string
  description = "An existing KMS key (CMK) to use for ECR repository encryption, given as a key ID, key ARN, alias name, or alias ARN. ECR repository encryption is set at creation and is immutable, so changing this on an existing install replaces the repository. If empty, ECR uses the AWS-managed aws/ecr key."
  default     = ""
}

variable "cloudwatch_logs_encryption_kms_key_id" {
  type        = string
  description = "An existing KMS key (CMK) to use for the EKS control plane CloudWatch log group, given as a key ID, key ARN, alias name, or alias ARN. The key policy must allow `logs.<region>.amazonaws.com` to use the key or the log group cannot be created or updated. If empty, CloudWatch Logs uses its own default encryption."
  default     = ""
}

variable "cluster_addons" {
  type        = any
  description = "EKS cluster addons to merge on top of the built-in defaults (coredns, eks-pod-identity-agent, kube-proxy, vpc-cni). Provide a map keyed by addon name to override or extend defaults. Set a key to `null` to remove a default addon."
  default     = {}
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

variable "enable_ingress_nginx" {
  type        = string
  default     = "true"
  description = "Whether or not to deploy the ingress-nginx helm release within the nuon_dns module."
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
