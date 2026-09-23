locals {
  cilium = {
    name      = "cilium"
    namespace = "kube-system"
    version   = var.cilium_version
    enabled   = local.enable_cilium

    # kube-proxy is not installed when cilium owns the datapath, so the agents
    # need to reach the API server directly rather than via a ClusterIP.
    k8s_service_host = replace(module.eks.cluster_endpoint, "https://", "")
    k8s_service_port = 443
  }
}

# ---------------------------------------------------------------
# IAM
#
# In ENI IPAM mode the cilium-operator allocates ENIs and secondary
# IPs on behalf of nodes, so pods keep VPC-routable addresses and
# ALB target-type ip keeps working.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "cilium_operator" {
  count = local.cilium.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }
}

module "cilium_irsa" {
  count = local.cilium.enabled ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.0"

  role_name = "cilium-operator-${var.nuon_id}"

  role_policy_arns = {
    operator = aws_iam_policy.cilium_operator[0].arn
  }

  oidc_providers = {
    k8s = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.cilium.namespace}:cilium-operator"]
    }
  }

  tags = local.tags
}

resource "aws_iam_policy" "cilium_operator" {
  count = local.cilium.enabled ? 1 : 0

  name_prefix = "cilium-operator-"
  description = "Allows the cilium-operator to manage ENIs for ENI IPAM mode."
  policy      = data.aws_iam_policy_document.cilium_operator[0].json

  tags = local.tags
}

# ---------------------------------------------------------------
# Cilium
#
# Installed before every other helm release: with no VPC CNI the
# nodes stay NotReady until the cilium agents land and write a CNI
# config, and helm_release waits on readiness by default.
# ---------------------------------------------------------------

resource "helm_release" "cilium" {
  count = local.cilium.enabled ? 1 : 0

  provider = helm.main

  namespace        = local.cilium.namespace
  create_namespace = false

  name       = local.cilium.name
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = local.cilium.version

  # The agents have to schedule onto NotReady, tainted nodes to bring
  # the datapath up at all, so give them room to do it.
  wait    = true
  timeout = 900

  values = concat(
    [yamlencode({
      cluster : {
        name : module.eks.cluster_name
      }

      # Pods get VPC IPs from ENIs rather than an overlay, which keeps
      # alb.ingress.kubernetes.io/target-type ip usable.
      ipam : {
        mode : "eni"
      }
      eni : {
        enabled : true
        awsEnablePrefixDelegation : true
        awsReleaseExcessIPs : true
      }
      routingMode : "native"
      endpointRoutes : {
        enabled : true
      }
      egressMasqueradeInterfaces : "eth+"

      # No kube-proxy, so cilium provides service handling and needs a
      # direct route to the API server to bootstrap.
      kubeProxyReplacement : true
      k8sServiceHost : local.cilium.k8s_service_host
      k8sServicePort : local.cilium.k8s_service_port

      hubble : {
        enabled : true
        relay : {
          enabled : true
          tolerations : local.cilium_tolerations
        }
        ui : {
          enabled : true
          tolerations : local.cilium_tolerations
        }
      }

      operator : {
        replicas : 1
        tolerations : local.cilium_tolerations
      }

      # The chart takes operator SA annotations here, not under operator.
      serviceAccounts : {
        operator : {
          annotations : {
            "eks.amazonaws.com/role-arn" : module.cilium_irsa[0].iam_role_arn
          }
        }
      }
    })],
    var.cilium_extra_helm_values == null ? [] : [yamlencode(var.cilium_extra_helm_values)],
  )

  depends_on = [
    module.eks,
    module.cilium_irsa,
    resource.aws_security_group_rule.runner_cluster_access,
  ]
}

locals {
  cilium_tolerations = [
    {
      key    = "karpenter.sh/controller"
      value  = "true"
      effect = "NoSchedule"
    },
    {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NoSchedule"
    },
  ]
}
