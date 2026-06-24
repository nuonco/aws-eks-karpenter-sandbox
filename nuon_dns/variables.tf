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

variable "enable_ingress_nginx" {
  type        = bool
  default     = true
  description = "Whether or not to deploy the ingress-nginx helm release."
}

variable "enable_cert_manager" {
  type        = bool
  default     = true
  description = "Whether or not to deploy the cert-manager helm release, its IRSA role, and the cert-manager cluster issuers."
}

variable "enable_alb_ingress_controller" {
  type        = bool
  default     = true
  description = "Whether or not to deploy the aws-load-balancer-controller helm release and its IRSA role."
}

variable "enable_external_dns" {
  type        = bool
  default     = true
  description = "Whether or not to deploy the external-dns helm release and its IRSA role."
}
