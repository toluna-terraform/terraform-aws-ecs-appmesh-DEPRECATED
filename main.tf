locals {
  # ECS SG rules
  security_cidr = split(",", data.aws_ssm_parameter.security_cidr.value)

  dockerLabels                  = jsonencode(var.dockerLabels)
  app_container_environment     = jsonencode(var.app_container_environment)
  envoy_dockerLabels            = jsonencode(var.envoy_dockerLabels)
  envoy_container_environment   = jsonencode(var.envoy_container_environment)
  app_container_secrets         = jsonencode(var.app_container_secrets)
  datadog_container_secrets     = jsonencode(var.datadog_container_secrets)
  datadog_container_environment = jsonencode(var.datadog_container_environment)
  datadog_dockerLabels          = jsonencode(var.datadog_dockerLabels)
}