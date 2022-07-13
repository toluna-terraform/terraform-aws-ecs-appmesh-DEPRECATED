<!-- BEGIN_TF_DOCS -->
# terraform-aws-ecs
Toluna terraform module for AWS ECS APP MESH

## Description
This module creates an ECS cluster, ECS service, Task definition and IAM role for task excution.

## Usage
```hcl
module "ecs" {
  source                = "toluna-terraform/ecs-appmesh/aws"
  version               = "~>0.0.1" // Change to the required version.
  region                        = local.region
  app_name                      = local.app_name
  environment                   = local.env_name
  env_type                      = local.env_vars.env_type
  aws_profile                   = local.aws_profile
  vpc_id                        = local.vpc_id
  app_mesh_owner                = data.aws_caller_identity.mesh_owner.id
  app_mesh_name                 = local.env_vars.app_mesh_name
  app_mesh_env                  = local.env_vars.app_mesh_account
  namespace                     = local.namespace
  namespace_id                  = data.terraform_remote_state.shared.outputs.shared_namespace[0]["${local.env_vars.app_mesh_name}.${local.env_vars.app_mesh_account}.local"].id
  ecs_service_desired_count     = local.env_vars.ecs_service_desired_count
  ecr_repo_url                  = local.ecr_repo_url
  aws_cloudwatch_log_group_name = local.aws_cloudwatch_log_group
  subnet_ids                    = local.subnet_ids
  app_container_environment     = local.app_container_environment
  envoy_container_environment   = local.envoy_container_environment
  envoy_dockerLabels            = local.envoy_dockerLabels
  datadog_container_environment = local.dd_container_environment
  datadog_dockerLabels          = local.dd_dockerLabels
  datadog_container_secrets     = local.dd_container_secrets
  app_container_secrets         = local.app_container_secrets
  app_container_image           = "${local.ecr_repo_url}:${local.env_vars.from_env}"
  create_datadog                = true
  task_definition_cpu           = 512
  task_definition_memory        = 2048
  app_container_memory          = 2048
  backends                      = local.env_vars.backends #list of backends for the service
  external_services             = local.env_vars.external_services #list of external service
  access_by_gateway_route       = true # create a route to the app mesh gateway
  integrator_external_services  = local.env_vars.external_services # list of external services (accessed by nginx with nat)
}
```
## Requirements

No requirements.

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_aws.app_mesh"></a> [aws.app\_mesh](#provider\_aws.app\_mesh) | n/a |
| <a name="provider_external"></a> [external](#provider\_external) | n/a |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appmesh_gateway_route.net](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_gateway_route) | resource |
| [aws_appmesh_route.integrators](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_route) | resource |
| [aws_appmesh_route.net](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_route) | resource |
| [aws_appmesh_virtual_node.td_net](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_virtual_node) | resource |
| [aws_appmesh_virtual_router.integrator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_virtual_router) | resource |
| [aws_appmesh_virtual_router.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_virtual_router) | resource |
| [aws_appmesh_virtual_service.integrator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_virtual_service) | resource |
| [aws_appmesh_virtual_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appmesh_virtual_service) | resource |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.app_mesh_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.datadog_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.cloud-watch-policy-attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs-task-execution-role-policy-attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.envoy-policy-attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm-role-policy-attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.ecs_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_service_discovery_service.net](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.appmesh_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_prefix_list.private_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/prefix_list) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.security_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [external_external.current_service_image](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [template_file.default-container](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_by_gateway_route"></a> [access\_by\_gateway\_route](#input\_access\_by\_gateway\_route) | Boolean which initiates if service is added to App mesh gatway | `bool` | `false` | no |
| <a name="input_app_container_cpu"></a> [app\_container\_cpu](#input\_app\_container\_cpu) | Default container cpu | `number` | `2` | no |
| <a name="input_app_container_environment"></a> [app\_container\_environment](#input\_app\_container\_environment) | The environment variables to pass to a container | `list(map(string))` | `[]` | no |
| <a name="input_app_container_image"></a> [app\_container\_image](#input\_app\_container\_image) | App container image | `string` | n/a | yes |
| <a name="input_app_container_memory"></a> [app\_container\_memory](#input\_app\_container\_memory) | Default container memory | `number` | `4096` | no |
| <a name="input_app_container_port"></a> [app\_container\_port](#input\_app\_container\_port) | Default container port | `number` | `80` | no |
| <a name="input_app_container_secrets"></a> [app\_container\_secrets](#input\_app\_container\_secrets) | The secrets to pass to the app container | `list(map(string))` | `[]` | no |
| <a name="input_app_mesh_env"></a> [app\_mesh\_env](#input\_app\_mesh\_env) | The mesh name | `string` | n/a | yes |
| <a name="input_app_mesh_name"></a> [app\_mesh\_name](#input\_app\_mesh\_name) | The mesh name | `string` | n/a | yes |
| <a name="input_app_mesh_owner"></a> [app\_mesh\_owner](#input\_app\_mesh\_owner) | The mesh owner id | `string` | n/a | yes |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | app name | `string` | n/a | yes |
| <a name="input_aws_cloudwatch_log_group_name"></a> [aws\_cloudwatch\_log\_group\_name](#input\_aws\_cloudwatch\_log\_group\_name) | Cloud watch log group name | `string` | n/a | yes |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | profile | `string` | n/a | yes |
| <a name="input_backends"></a> [backends](#input\_backends) | List of backends for ocastrator | `list(string)` | `[]` | no |
| <a name="input_create_datadog"></a> [create\_datadog](#input\_create\_datadog) | Boolean which initiate datadog container creation or not | `bool` | `false` | no |
| <a name="input_datadog_container_cpu"></a> [datadog\_container\_cpu](#input\_datadog\_container\_cpu) | Datadog container cpu | `number` | `10` | no |
| <a name="input_datadog_container_environment"></a> [datadog\_container\_environment](#input\_datadog\_container\_environment) | Datadog container environment variables | `list(map(string))` | `[]` | no |
| <a name="input_datadog_container_image"></a> [datadog\_container\_image](#input\_datadog\_container\_image) | Datadog container image | `string` | `"datadog/agent:latest"` | no |
| <a name="input_datadog_container_memoryreservation"></a> [datadog\_container\_memoryreservation](#input\_datadog\_container\_memoryreservation) | Datadog container memory | `number` | `256` | no |
| <a name="input_datadog_container_name"></a> [datadog\_container\_name](#input\_datadog\_container\_name) | Datadog container name | `string` | `"datadog_agent"` | no |
| <a name="input_datadog_container_port"></a> [datadog\_container\_port](#input\_datadog\_container\_port) | Datadog container port | `number` | `8126` | no |
| <a name="input_datadog_container_secrets"></a> [datadog\_container\_secrets](#input\_datadog\_container\_secrets) | The secrets to pass to the datadog container | `list(map(string))` | `[]` | no |
| <a name="input_datadog_dockerLabels"></a> [datadog\_dockerLabels](#input\_datadog\_dockerLabels) | A key/value map of labels to add to the container | `map(string)` | `{}` | no |
| <a name="input_dockerLabels"></a> [dockerLabels](#input\_dockerLabels) | A key/value map of labels to add to the container | `map(string)` | `{}` | no |
| <a name="input_ecr_repo_url"></a> [ecr\_repo\_url](#input\_ecr\_repo\_url) | ecr repo url | `string` | n/a | yes |
| <a name="input_ecs_security_group_additional_rules"></a> [ecs\_security\_group\_additional\_rules](#input\_ecs\_security\_group\_additional\_rules) | List of additional security group rules to add to the security group created | `any` | `{}` | no |
| <a name="input_ecs_service_desired_count"></a> [ecs\_service\_desired\_count](#input\_ecs\_service\_desired\_count) | ecs service desired count | `number` | n/a | yes |
| <a name="input_env_type"></a> [env\_type](#input\_env\_type) | prod \|\| non-prod | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | environment | `string` | n/a | yes |
| <a name="input_envoy_app_ports"></a> [envoy\_app\_ports](#input\_envoy\_app\_ports) | The app ports for envoy to listen to | `string` | `"80"` | no |
| <a name="input_envoy_container_environment"></a> [envoy\_container\_environment](#input\_envoy\_container\_environment) | The environment variables to pass to a container | `list(map(string))` | `[]` | no |
| <a name="input_envoy_dockerLabels"></a> [envoy\_dockerLabels](#input\_envoy\_dockerLabels) | A key/value map of labels to add to the container | `map(string)` | `{}` | no |
| <a name="input_external_services"></a> [external\_services](#input\_external\_services) | List of external services for integrator | `list(string)` | `[]` | no |
| <a name="input_iam_role_additional_policies"></a> [iam\_role\_additional\_policies](#input\_iam\_role\_additional\_policies) | Additional policies to be added to the IAM role | `list(string)` | `[]` | no |
| <a name="input_integrator_external_services"></a> [integrator\_external\_services](#input\_integrator\_external\_services) | Additional policies to be added to the IAM role | `list(string)` | `[]` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The app namespac | `string` | n/a | yes |
| <a name="input_namespace_id"></a> [namespace\_id](#input\_namespace\_id) | The app namespace id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Boolean which initiates if service is added to App mesh gatway | `string` | `"us-east-1"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs used in Service | `list(string)` | `null` | no |
| <a name="input_task_definition_cpu"></a> [task\_definition\_cpu](#input\_task\_definition\_cpu) | Task definition CPU | `number` | `2048` | no |
| <a name="input_task_definition_memory"></a> [task\_definition\_memory](#input\_task\_definition\_memory) | Task definition memory | `number` | `4096` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC id | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->