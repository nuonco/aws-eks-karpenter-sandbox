data "aws_iam_policy_document" "ecr" {
  // AmazonEC2ContainerRegistryFullAccess on the specific policy
  statement {
    effect    = "Allow"
    actions   = ["ecr:*", "cloudtrail:LookupEvents"]
    resources = [module.ecr.repository_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = [module.ecr.repository_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "replication.ecr.amazonaws.com"
      ]
    }
  }

}

resource "aws_iam_policy" "ecr_access" {
  name   = "ecr-access-${var.nuon_id}"
  policy = data.aws_iam_policy_document.ecr.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_access_provision" {
  role       = local.roles.provision_iam_role_name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "ecr_access_maintenance" {
  role       = local.roles.maintenance_iam_role_name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "ecr_access_deprovision" {
  role       = local.roles.deprovision_iam_role_name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "ecr_access_break_glass" {
  count      = var.break_glass_iam_role_arn != "" ? 1 : 0
  role       = local.roles.break_glass_iam_role_name
  policy_arn = aws_iam_policy.ecr_access.arn
}
