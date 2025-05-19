# Nuon DNS

## Requirements

| Name                                                                        | Version   |
| --------------------------------------------------------------------------- | --------- |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                      | >= 5.94.1 |
| <a name="requirement_helm"></a> [helm](#requirement_helm)                   | >= 2.17.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement_kubectl)          | >= 1.19   |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement_kubernetes) | >= 2.36.0 |

## Providers

| Name                                                         | Version   |
| ------------------------------------------------------------ | --------- |
| <a name="provider_aws"></a> [aws](#provider_aws)             | >= 5.94.1 |
| <a name="provider_helm"></a> [helm](#provider_helm)          | >= 2.17.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider_kubectl) | >= 1.19   |

## Modules

| Name                                                                                         | Source                                                                   | Version |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ------- |
| <a name="module_alb_controller_irsa"></a> [alb_controller_irsa](#module_alb_controller_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.0  |
| <a name="module_cert_manager_irsa"></a> [cert_manager_irsa](#module_cert_manager_irsa)       | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.0  |
| <a name="module_external_dns_irsa"></a> [external_dns_irsa](#module_external_dns_irsa)       | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.0  |

## Resources

| Name                                                                                                                                   | Type     |
| -------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_route53_record.caa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                   | resource |
| [aws_route53_zone.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)                  | resource |
| [aws_route53_zone.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)                    | resource |
| [helm_release.alb_ingress_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release)            | resource |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release)                      | resource |
| [helm_release.external_dns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release)                      | resource |
| [helm_release.ingress_nginx](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release)                     | resource |
| [kubectl_manifest.internal_cluster_issuer](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.public_cluster_issuer](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest)   | resource |

## Inputs

| Name                                                                                             | Description                                                                       | Type       | Default | Required |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- | ---------- | ------- | :------: |
| <a name="input_eks_cluster_name"></a> [eks_cluster_name](#input_eks_cluster_name)                | The name of the EKS Cluster created in eks.tf                                     | `string`   | n/a     |   yes    |
| <a name="input_eks_oidc_provider_arn"></a> [eks_oidc_provider_arn](#input_eks_oidc_provider_arn) | The EKS Cluster OIDC Provider ARN                                                 | `string`   | n/a     |   yes    |
| <a name="input_internal_root_domain"></a> [internal_root_domain](#input_internal_root_domain)    | The internal root domain.                                                         | `string`   | n/a     |   yes    |
| <a name="input_nuon_id"></a> [nuon_id](#input_nuon_id)                                           | The nuon id for this install. Used for naming purposes.                           | `string`   | n/a     |   yes    |
| <a name="input_public_root_domain"></a> [public_root_domain](#input_public_root_domain)          | The public root domain.                                                           | `string`   | n/a     |   yes    |
| <a name="input_region"></a> [region](#input_region)                                              | The region the cluster is in.                                                     | `string`   | n/a     |   yes    |
| <a name="input_tags"></a> [tags](#input_tags)                                                    | List of custom tags to add to the install resources. Used for taxonomic purposes. | `map(any)` | n/a     |   yes    |
| <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)                                              | The ID of the AWS VPC to provision the sandbox in.                                | `string`   | n/a     |   yes    |

## Outputs

| Name                                                                                                  | Description |
| ----------------------------------------------------------------------------------------------------- | ----------- |
| <a name="output_alb_ingress_controller"></a> [alb_ingress_controller](#output_alb_ingress_controller) | n/a         |
| <a name="output_cert_manager"></a> [cert_manager](#output_cert_manager)                               | n/a         |
| <a name="output_external_dns"></a> [external_dns](#output_external_dns)                               | n/a         |
| <a name="output_ingress_nginx"></a> [ingress_nginx](#output_ingress_nginx)                            | n/a         |
| <a name="output_internal_domain"></a> [internal_domain](#output_internal_domain)                      | n/a         |
| <a name="output_public_domain"></a> [public_domain](#output_public_domain)                            | n/a         |
