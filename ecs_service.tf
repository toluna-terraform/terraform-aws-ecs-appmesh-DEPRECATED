resource "aws_service_discovery_service" "net" {
  name = "${var.env_name}"
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
  name       = "vr-${var.app_name}-${var.env_name}"
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
  name       = "${var.env_name}.${var.namespace}"
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

# adding a main route
resource "aws_appmesh_route" "main-route" {
  name                = "route-${var.app_name}-${var.env_name}"
  mesh_name           = "${var.app_mesh_name}"
  mesh_owner          = "${var.app_mesh_owner}"
  virtual_router_name = aws_appmesh_virtual_router.service.name
  spec {
    priority = 2
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = "vn-${var.app_name}-${var.env_name}-green"
          weight       = 100
        }
        weighted_target {
          virtual_node = "vn-${var.app_name}-${var.env_name}-blue"
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

# adding a test route
resource "aws_appmesh_route" "test-route" {
  name                = "route-${var.app_name}-${var.env_name}-test"
  mesh_name           = "${var.app_mesh_name}"
  mesh_owner          = "${var.app_mesh_owner}"
  virtual_router_name = aws_appmesh_virtual_router.service.name
  spec {
    # this route is for testing, and will have an additional header
    priority = 1
    http_route {
      match {
        prefix = "/"
        header {
          name = "test-header"
          match {
            exact = "test-value"
          }
        }
      }

      action {
        weighted_target {
          virtual_node = "vn-${var.app_name}-${var.env_name}-green"
          weight       = 100
        }
        weighted_target {
          virtual_node = "vn-${var.app_name}-${var.env_name}-blue"
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
      spec[0].http_route[1].action
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
  name                 = "gw-${var.app_mesh_name}-${var.app_name}-${var.env_name}-route"
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
        prefix = var.env_name == var.app_mesh_name ? "/${var.app_name}" : "/${var.env_name}/${var.app_name}"
      }
    }
  }
}

resource "aws_appmesh_virtual_router" "integrator" {
  for_each  = toset(var.integrator_external_services)
  name      = "vr-${split(".", each.key)[0]}-${var.env_name}"
  mesh_name = var.env_name

  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }
  }
}

resource "aws_appmesh_virtual_service" "integrator" {
  for_each  = toset(var.integrator_external_services)
  name      = "${each.key}"
  mesh_name = var.env_name

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.integrator[each.key].name
      }
    }
  }
}

resource "aws_appmesh_route" "integrators" {
  for_each  = toset(var.integrator_external_services)
  name                = "route-${split(".", each.key)[0]}-${var.env_name}"
  mesh_name           = var.env_name
  virtual_router_name = aws_appmesh_virtual_router.integrator[each.key].name
  spec {
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = "vn-integrator-${var.env_name}-green"
          weight       = 100
        }
        weighted_target {
          virtual_node = "vn-integrator-${var.env_name}-blue"
          weight       = 0
        }
      }
    }
  }
  # Ignoring changes made by code_deploy controller
  lifecycle {
    ignore_changes = [
      spec[0].http_route[0].action
    ]
  }
}
