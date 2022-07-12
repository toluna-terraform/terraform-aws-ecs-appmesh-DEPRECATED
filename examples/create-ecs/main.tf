locals {

  app_container_environment = [
    {
      "name" : "ASPNETCORE_ENVIRONMENT",
      "value" : "${split("-", local.environment)[0]}"
    },
    {
      "name" : "APP_NAME",
      "value" : "${local.app_name}"
    },
  ]

  envoy_container_environment = [
    { "name" : "APPMESH_RESOURCE_ARN", "value" : "arn:aws:appmesh:us-east-1:${data.aws_caller_identity.aws_profile.id}:mesh/${local.env_name}@${data.aws_caller_identity.mesh_owner.id}/virtualNode/vn-${local.app_name}-${local.env_name}-{BG_COLOR}" },
    { "name" : "ENABLE_ENVOY_DATADOG_TRACING", "value" : "true" },
    { "name" : "ENVOY_LOG_LEVEL", "value" : "off" },
    { "name" : "DATADOG_TRACER_PORT", "value" : "8126" }
  ]
  envoy_dockerLabels = {
    "com.datadoghq.ad.instances" : "[{\"stats_url\": \"http://%%host%%:9901/stats\"}]",
    "com.datadoghq.ad.check_names" : "[\"envoy\"]",
    "com.datadoghq.ad.init_configs" : "[{}]"
  }

  dd_container_environment = [
    { "name" : "DD_ENV", "value" : "${local.env_vars.app_mesh_name}.${local.env_vars.app_mesh_account}" },
    { "name" : "DD_SERVICE", "value" : "${local.app_name}" },
    { "name" : "DD_VERSION", "value" : "0.0.1" },
    { "name" : "DD_APM_DD_URL", "value" : "https://trace.agent.datadoghq.com" },
    { "name" : "DD_APM_ENABLED","value" : "true" },
    { "name" : "DD_APM_NON_LOCAL_TRAFFIC", "value" : "true" },
    { "name" : "DD_DOCKER_ENV_AS_TAGS", "value" : "true" },
    { "name" : "DD_DOCKER_LABELS_AS_TAGS", "value" : "true" },
    { "name" : "ECS_FARGATE", "value" : "true" },
    { "name" : "DD_SITE", "value" : "datadoghq.com" },
    { "name" : "DD_USE_PROXY_FOR_CLOUD_METADATA", "value" : "true" }
  ]
  dd_dockerLabels = {
        "com.datadoghq.ad.logs" : "[{\"service\": \"${local.app_name}\"}]",
        "com.datadoghq.ad.instances" : "[{\"stats_url\": \"http://%%host%%:9901/stats\"}]",
        "com.datadoghq.ad.check_names" : "[\"envoy\"]",
        "com.datadoghq.ad.init_configs" : "[{}]",
        "com.datadoghq.tags.env" : "${local.env_vars.app_mesh_name}.${local.env_vars.app_mesh_account}",
        "com.datadoghq.tags.service" : "${local.app_name}",
        "com.datadoghq.tags.version" : "0.0.1"
  }
  dd_container_secrets = [
    { "name" : "DD_API_KEY", "valueFrom" : "/${data.aws_caller_identity.aws_profile.account_id}/datadog/api-key" }
  ]
  app_container_secrets = []

}


module "ecs" {
  source = "../../"
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
}
