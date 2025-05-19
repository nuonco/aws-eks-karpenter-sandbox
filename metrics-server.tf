resource "helm_release" "metrics_server" {
  namespace        = "metrics-server"
  create_namespace = true

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.8.2"

  provider = helm.main

  values = [
    yamlencode({
      tolerations : [
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
  ]

  depends_on = [
    helm_release.ebs_csi
  ]
}
