variable "eks_cluster_name" {
  type        = string
  description = "The name of the EKS Cluster created in eks.tf"
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "The EKS Cluster OIDC Provider ARN"
}

variable "internal_root_domain" {
  type        = string
  description = "The internal root domain."
}

variable "public_root_domain" {
  type        = string
  description = "The public root domain."
}

variable "vpc_id" {
  type        = string
  description = "The ID of the AWS VPC to provision the sandbox in."
}

variable "region" {
  type        = string
  description = "The region the cluster is in."
}

variable "tags" {
  type        = map(any)
  description = "List of custom tags to add to the install resources. Used for taxonomic purposes."
}

variable "nuon_id" {
  type        = string
  description = "The nuon id for this install. Used for naming purposes."
}
