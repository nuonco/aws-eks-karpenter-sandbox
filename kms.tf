locals {
  create_cluster_kms_key = var.cluster_encryption_kms_key_id == ""
  cluster_kms_key_arn    = local.create_cluster_kms_key ? aws_kms_key.eks[0].arn : data.aws_kms_key.cluster_encryption[0].arn

  ebs_kms_key_arn             = var.ebs_encryption_kms_key_id != "" ? data.aws_kms_key.ebs_encryption[0].arn : null
  ecr_kms_key_arn             = var.ecr_encryption_kms_key_id != "" ? data.aws_kms_key.ecr_encryption[0].arn : null
  cloudwatch_logs_kms_key_arn = var.cloudwatch_logs_encryption_kms_key_id != "" ? data.aws_kms_key.cloudwatch_logs_encryption[0].arn : null
}

resource "aws_kms_key" "eks" {
  count = local.create_cluster_kms_key ? 1 : 0

  description = "Key for ${local.cluster_name} EKS cluster"
}

moved {
  from = aws_kms_key.eks
  to   = aws_kms_key.eks[0]
}

data "aws_kms_key" "cluster_encryption" {
  count = local.create_cluster_kms_key ? 0 : 1

  key_id = var.cluster_encryption_kms_key_id
}

data "aws_kms_key" "ebs_encryption" {
  count = var.ebs_encryption_kms_key_id != "" ? 1 : 0

  key_id = var.ebs_encryption_kms_key_id
}

data "aws_kms_key" "ecr_encryption" {
  count = var.ecr_encryption_kms_key_id != "" ? 1 : 0

  key_id = var.ecr_encryption_kms_key_id
}

data "aws_kms_key" "cloudwatch_logs_encryption" {
  count = var.cloudwatch_logs_encryption_kms_key_id != "" ? 1 : 0

  key_id = var.cloudwatch_logs_encryption_kms_key_id
}
