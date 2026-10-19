// install karpenter CRDS
// install karpenter
// create default ec2 nodeclass and default nodepool
locals {
  karpenter = {
    cluster_name          = local.cluster_name
    namespace             = "kube-system"
    version               = var.karpenter_version
    discovery_key         = "karpenter.sh/discovery"
    discovery_value       = local.cluster_name
    instance_profile_name = "KarpenterNodeInstanceProfile-${local.cluster_name}"
    zone_prefix           = join("-", slice(split("-", var.region), 0, 1))
  }
}

data "aws_iam_policy_document" "karpenter_node_assume_role" {
  count = var.karpenter_on_fargate ? 1 : 0

  statement {
    sid     = "EKSNodeAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_node" {
  count = var.karpenter_on_fargate ? 1 : 0

  name_prefix           = "karpenter-node-"
  assume_role_policy    = one(data.aws_iam_policy_document.karpenter_node_assume_role[*].json)
  force_detach_policies = true

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = {
    for k, v in {
      AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    } : k => v if var.karpenter_on_fargate
  }

  role       = one(aws_iam_role.karpenter_node[*].name)
  policy_arn = each.value
}

# the karpenter module can't create an access entry for an external node role
resource "aws_eks_access_entry" "karpenter_node" {
  count = var.karpenter_on_fargate ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = one(aws_iam_role.karpenter_node[*].arn)
  type          = "EC2_LINUX"

  tags = local.tags
}

locals {
  karpenter_node_iam_role_name = concat(
    aws_iam_role.karpenter_node[*].name,
    [for ng in values(module.eks.eks_managed_node_groups) : ng.iam_role_name],
  )[0]
  karpenter_node_iam_role_arn = concat(
    aws_iam_role.karpenter_node[*].arn,
    [for ng in values(module.eks.eks_managed_node_groups) : ng.iam_role_arn],
  )[0]
}

# NOTE: we use an instance_profile because the role changes between provisions
#       but the role is immutable on the ec2nodeclass
resource "aws_iam_instance_profile" "karpenter" {
  name = local.karpenter.instance_profile_name
  role = local.karpenter_node_iam_role_name
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.33.1"

  cluster_name        = local.karpenter.cluster_name
  namespace           = local.karpenter.namespace
  create_access_entry = false

  create_node_iam_role = false
  node_iam_role_arn    = local.karpenter_node_iam_role_arn

  create_instance_profile = false

  enable_v1_permissions = true

  enable_irsa                     = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["kube-system:karpenter"]
  iam_role_tags = merge(local.tags, {
    karpenter = true
  })

  queue_name = "karpenter-${var.nuon_id}"

  iam_policy_statements = local.ebs_kms_key_arn == null ? [] : [
    {
      sid       = "AllowKMSGrantForEBSEncryption"
      actions   = ["kms:CreateGrant"]
      resources = [local.ebs_kms_key_arn]
      conditions = [{
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }]
    },
    {
      sid = "AllowKMSUseForEBSEncryption"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncrypt*",
      ]
      resources  = [local.ebs_kms_key_arn]
      conditions = []
    },
  ]

  depends_on = [
    module.eks,
    resource.aws_security_group_rule.runner_cluster_access,
    aws_iam_role_policy_attachment.karpenter_node,
    aws_eks_access_entry.karpenter_node,
  ]
}

resource "helm_release" "karpenter_crd" {
  provider = helm.main

  namespace        = local.karpenter.namespace
  create_namespace = false

  chart      = "karpenter-crd"
  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  version    = local.karpenter.version

  wait = true

  values = [
    yamlencode({
      karpenter_namespace = local.karpenter.namespace
      webhook = {
        enabled     = true
        serviceName = "karpenter"
        port        = 8443
      }
    }),
  ]

  depends_on = [
    module.karpenter
  ]
}

resource "helm_release" "karpenter" {
  provider = helm.main

  namespace        = local.karpenter.namespace
  create_namespace = false

  chart      = "karpenter"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  version    = local.karpenter.version

  # https://github.com/aws/karpenter-provider-aws/blob/v1.2.2/charts/karpenter/values.yaml
  values = concat(
    [yamlencode({
      replicas : var.karpenter_replica_count
      logLevel : "debug"
      settings : {
        clusterEndpoint : module.eks.cluster_endpoint
        clusterName : local.karpenter.cluster_name
        interruptionQueue : module.karpenter.queue_name
        batchMaxDuration : "15s" # a little longer than the default
      }
      dnsPolicy : "ClusterFirst"
      controller : {
        resources : {
          requests : {
            cpu : 1
            memory : var.karpenter_on_fargate ? "2Gi" : "1Gi"
          }
          limits : {
            cpu : 1
            memory : var.karpenter_on_fargate ? "2Gi" : "1Gi"
          }
        }
      }
      serviceAccount : {
        annotations : {
          "eks.amazonaws.com/role-arn" : module.karpenter.iam_role_arn
        }
      }
      tolerations : [
        {
          key : "karpenter.sh/controller"
          value : "true"
          effect : "NoSchedule"
        },
        {
          key : "CriticalAddonsOnly"
          value : "true"
          effect : "NoSchedule"
        },
      ]
    })],
    var.karpenter_extra_helm_values != null ? [yamlencode(var.karpenter_extra_helm_values)] : []
  )

  lifecycle {
    ignore_changes = [
      repository_password
    ]
  }

  depends_on = [
    helm_release.karpenter_crd
  ]
}

#
# EC2NodeClass: default
# https://karpenter.sh/v1.0/concepts/nodeclasses/
#
locals {
  # https://karpenter.sh/v1.0/concepts/nodeclasses/#specamiselectorterms
  default_nodeclass_default_ami_selector_terms = [
    {
      alias = "al2023@latest"
    }
  ]
  # terraform's dumb type system gets confused if we use a ternary (x ? x : y)
  # to choose between these, so we have do trick it with a conditional list
  # index. bad terraform.
  default_nodeclass_ami_selector_terms = [
    var.karpenter_default_nodeclass_ami_selector_terms,
    local.default_nodeclass_default_ami_selector_terms,
  ][var.karpenter_default_nodeclass_ami_selector_terms != null ? 0 : 1]
}

resource "kubectl_manifest" "karpenter_ec2nodeclass_default" {
  provider = kubectl.main

  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    # merge in blockDeviceMappings only when set, so the AMI's default root
    # volume is preserved when the var is null
    spec = merge({
      instanceProfile  = "KarpenterNodeInstanceProfile-${local.karpenter.cluster_name}"
      amiSelectorTerms = local.default_nodeclass_ami_selector_terms
      # without this, pods on karpenter nodes can't use the IAM node role
      # https://github.com/aws/karpenter-provider-aws/issues/7548#issuecomment-2558191953
      metadataOptions = var.karpenter_ec2nodeclass_default_metadata_options
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.karpenter.discovery_value
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.karpenter.discovery_value
          }
        }
      ]
      tags = local.tags
      }, var.karpenter_default_nodeclass_block_device_mappings != null ? {
      blockDeviceMappings = var.karpenter_default_nodeclass_block_device_mappings
    } : {})
  })

  depends_on = [
    helm_release.karpenter,
    aws_iam_instance_profile.karpenter,
  ]
}

#
# nodepool: default
#
locals {
  default_nodepool_default_spec = {
    limits = {
      cpu    = 100
      memory = "200Gi"
    }
    template = {
      spec = {
        expireAfter = "732h"
        nodeClassRef = {
          group = "karpenter.k8s.aws"
          kind  = "EC2NodeClass"
          name  = "default"
        }
        requirements = [
          {
            key      = "karpenter.sh/capacity-type"
            operator = "In"
            values = [
              "on-demand",
            ]
          },
          {
            "key"      = "node.kubernetes.io/instance-type"
            "operator" = "In"
            "values"   = [var.default_instance_type]
          },
          {
            key      = "topology.kubernetes.io/zone"
            operator = "In"
            values = [ // this requires refinement
              "${var.region}a",
              "${var.region}b",
              "${var.region}c",
            ]
          },
        ]
      }
    }
    # https://karpenter.sh/v1.0/concepts/disruption/
    disruption = {
      consolidationPolicy = "WhenEmptyOrUnderutilized"
      consolidateAfter    = "5m"
      budgets = [
        // only allow one node to be disrupted at once
        {
          nodes = "1",
        },
      ]
    }
  }
  # terraform's dumb type system gets confused if we use a ternary (x ? x : y)
  # to choose between these, so we have do trick it with a conditional list
  # index. bad terraform.
  default_nodepool_spec = [
    var.karpenter_default_nodepool_spec,
    local.default_nodepool_default_spec,
  ][var.karpenter_default_nodepool_spec != null ? 0 : 1]
}
resource "kubectl_manifest" "karpenter_nodepool_default" {
  provider = kubectl.main

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1" # we are on v1 now
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = local.default_nodepool_spec
  })

  depends_on = [
    kubectl_manifest.karpenter_ec2nodeclass_default,
    helm_release.karpenter,
  ]
}
