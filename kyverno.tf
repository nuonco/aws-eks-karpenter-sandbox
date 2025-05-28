locals {
  kyverno = {
    namespace  = "kyverno"
    value_file = "${path.module}/values/kyverno/values.yaml"
    default_policies = [
      "${path.module}/values/kyverno/policies/restrict-binding-system-groups.yaml",
      "${path.module}/values/kyverno/policies/restrict-secret-role-verbs.yaml",
    ]
  }
}

// install kyverno
resource "helm_release" "kyverno" {
  provider = helm.main

  namespace        = "kyverno"
  create_namespace = true

  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = "3.3.7" // TODO: make an input var?

  values = [
    file(local.kyverno.value_file),
  ]

  depends_on = [
    module.eks,
    resource.aws_security_group_rule.runner_cluster_access,
  ]
}

resource "kubectl_manifest" "default_policies" {
  provider = kubectl.main

  for_each  = toset(local.kyverno.default_policies)
  yaml_body = file(each.value)

  depends_on = [
    helm_release.kyverno
  ]
}

resource "kubectl_manifest" "vendor_policies" {
  provider = kubectl.main

  for_each = fileset(var.kyverno_policy_dir, "*.yaml")

  yaml_body = file("${var.kyverno_policy_dir}/${each.key}")

  depends_on = [
    helm_release.kyverno
  ]
}
