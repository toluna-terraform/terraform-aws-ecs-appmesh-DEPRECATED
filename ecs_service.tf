resource "aws_service_discovery_service" "net" {
  name = "${var.environment}"
  dns_config {
    namespace_id = var.namespace_id
    dns_records {
      ttl  = 300
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_appmesh_virtual_router" "service" {
  name       = "vr-${var.app_name}-${var.environment}"
  mesh_name  = "${var.app_mesh_name}"
  mesh_owner = "${var.app_mesh_owner}"

  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }
  }
}


resource "aws_appmesh_virtual_service" "service" {
  name       = "${var.environment}.${var.namespace}"
  mesh_name  = "${var.app_mesh_name}"
  mesh_owner = "${var.app_mesh_owner}"

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.service.name
      }
    }
  }
}

resource "aws_appmesh_route" "net" {
  name                = "route-${var.app_name}-${var.environment}"
  mesh_name           = "${var.app_mesh_name}"
  mesh_owner          = "${var.app_mesh_owner}"
  virtual_router_name = aws_appmesh_virtual_router.service.name
  spec {
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = "vn-${var.app_name}-${var.environment}-green"
          weight       = 100
        }
        weighted_target {
          virtual_node = "vn-${var.app_name}-${var.environment}-blue"
          weight       = 0
        }
      }
    }
  }
  depends_on = [
    aws_appmesh_virtual_node.td_net
  ]
  # Ignoring changes made by code_deploy controller
  lifecycle {
    ignore_changes = [
      spec[0].http_route[0].action
    ]
  }
}


resource "aws_ecs_service" "main" {
  for_each = toset(["blue","green"])
  name                = "${var.app_name}-${each.key}"
  cluster             = aws_ecs_cluster.ecs_cluster.id
  task_definition     = aws_ecs_task_definition.task_definition[each.key].arn
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"
  desired_count       = each.key == "green" ? var.ecs_service_desired_count : 0
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
  service_registries {
    registry_arn = aws_service_discovery_service.net.arn
  }

deployment_circuit_breaker {
  enable = true
  rollback = false
}

  # Ignoring changes made by code_deploy controller
  /* lifecycle {
    ignore_changes = [
      task_definition,desired_count
    ]
  } */
}

resource "aws_appmesh_gateway_route" "net" {
  count = var.access_by_gateway_route == true ? 1: 0
  provider             = aws.app_mesh
  name                 = "gw-${var.app_mesh_name}-${var.app_name}-${var.environment}-route"
  mesh_name            = var.app_mesh_name
  mesh_owner           = var.app_mesh_owner
  virtual_gateway_name = "gw-${var.app_mesh_name}"

  spec {
    http_route {
      action {
        target {
          virtual_service {
            virtual_service_name = aws_appmesh_virtual_service.service.name
          }
        }
      }

      match {
        prefix = var.environment == var.app_mesh_name ? "/${var.app_name}" : "/${var.environment}/${var.app_name}"
      }
    }
  }
}