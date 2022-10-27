

resource "aws_appmesh_virtual_node" "td_net" {
  for_each   = toset(["blue", "green"])
  name       = "vn-${var.app_name}-${var.env_name}-${each.key}"
  mesh_name  = var.app_mesh_name
  mesh_owner = "${var.app_mesh_owner}"
  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }

    dynamic "backend" {
      for_each = var.backends
      content {
        virtual_service {
          virtual_service_name = "${backend.value}.${var.app_mesh_name}.${var.app_mesh_env}.local"
        }
      }
    }
    dynamic "backend" {
      for_each = var.external_services
      content {
        virtual_service {
          virtual_service_name = "${backend.value}"
        }
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = var.env_name
        namespace_name = var.namespace
        
        attributes = {
          "ECS_SERVICE_NAME" = "${var.app_name}-${each.key}"
        }
      }
    }

    logging {
      access_log {
        file {
          path = "/dev/stdout"
        }
      }
    }
  }
}


resource "aws_ecs_task_definition" "task_definition" {
  for_each = toset(["blue","green"])
  family                   = "${var.app_name}-${var.env_name}-${each.key}"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  container_definitions    = "${replace(data.template_file.default-container.rendered, "{BG_COLOR}", each.key)}" 
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = var.task_definition_cpu
  memory                   = var.task_definition_memory
  proxy_configuration {
    type           = "APPMESH"
    container_name = "envoy"
    properties = {
      AppPorts         = var.envoy_app_ports
      EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
      IgnoredUID       = "1337"
      ProxyEgressPort  = 15001
      ProxyIngressPort = 15000
    }
  }
}

