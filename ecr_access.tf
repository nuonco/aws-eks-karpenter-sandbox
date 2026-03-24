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

resource "aws_iam_role_policy_attachment" "ecr_access" {
  for_each   = local.all_role_names
  role       = each.value
  policy_arn = aws_iam_policy.ecr_access.arn
}

# State migration: map old singular resources to new for_each keys
moved {
  from = aws_iam_role_policy_attachment.ecr_access_provision[0]
  to   = aws_iam_role_policy_attachment.ecr_access["provision-0"]
}

moved {
  from = aws_iam_role_policy_attachment.ecr_access_maintenance
  to   = aws_iam_role_policy_attachment.ecr_access["maintenance-0"]
}

moved {
  from = aws_iam_role_policy_attachment.ecr_access_deprovision[0]
  to   = aws_iam_role_policy_attachment.ecr_access["deprovision-0"]
}

resource "aws_iam_role_policy_attachment" "ecr_access_break_glass" {
  count      = var.break_glass_iam_role_arn != "" ? 1 : 0
  role       = local.roles.break_glass_iam_role_name
  policy_arn = aws_iam_policy.ecr_access.arn
}
