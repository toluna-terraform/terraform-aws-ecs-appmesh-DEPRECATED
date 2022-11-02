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


resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.app_name}-${var.env_name}"
}

resource "aws_service_discovery_service" "net" {
  name = var.env_name
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
  mesh_name  = var.app_mesh_name
  mesh_owner = var.app_mesh_owner

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
  mesh_name  = var.app_mesh_name
  mesh_owner = var.app_mesh_owner

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.service.name
      }
    }
  }
}

resource "aws_appmesh_route" "net" {
  name                = "route-${var.app_name}-${var.env_name}"
  mesh_name           = var.app_mesh_name
  mesh_owner          = var.app_mesh_owner
  virtual_router_name = aws_appmesh_virtual_router.service.name
  spec {
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


resource "aws_ecs_service" "main" {
  for_each            = toset(["blue", "green"])
  name                = "${var.app_name}-${each.key}"
  cluster             = aws_ecs_cluster.ecs_cluster.id
  task_definition     = aws_ecs_task_definition.task_definition.arn
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
    enable   = true
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
  count                = var.access_by_gateway_route == true ? 1 : 0
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
  mesh_owner = var.app_mesh_owner

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
  name      = each.key
  mesh_name = var.env_name
  mesh_owner = var.app_mesh_owner
  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.integrator[each.key].name
      }
    }
  }
}

resource "aws_appmesh_route" "integrators" {
  for_each            = toset(var.integrator_external_services)
  name                = "route-${split(".", each.key)[0]}-${var.env_name}"
  mesh_name           = var.env_name
  mesh_owner          = var.app_mesh_owner 
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



resource "aws_appmesh_virtual_node" "td_net" {
  for_each   = toset(["blue", "green"])
  name       = "vn-${var.app_name}-${var.env_name}-${each.key}"
  mesh_name  = var.app_mesh_name
  mesh_owner = var.app_mesh_owner
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
          virtual_service_name = "${backend.value}.${var.app_mesh_name}.${var.tribe_name}.local"
        }
      }
    }
    dynamic "backend" {
      for_each = var.external_services
      content {
        virtual_service {
          virtual_service_name = backend.value
        }
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = var.env_name
        namespace_name = var.namespace
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
  family                   = "${var.app_name}-${var.env_name}"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  container_definitions    = data.template_file.default-container.rendered
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


resource "aws_security_group" "ecs_sg" {
  name   = "${var.env_name}-${var.app_name}-ecs"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.security_cidr
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.env_name}-${var.app_name}-ecs"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "role-ecs-${var.app_name}-${var.env_name}"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": [
         "ecs-tasks.amazonaws.com",
         "ssm.amazonaws.com",
         "mediastore.amazonaws.com",
         "appmesh.amazonaws.com"
         ]
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ssm-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloud-watch-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "envoy-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
}

resource "aws_iam_role_policy" "app_mesh_policy" {
  name   = "policy-appmesh-${var.app_name}-${var.env_name}-${var.env_type}"
  role   = aws_iam_role.ecs_task_execution_role.name
  policy = data.aws_iam_policy_document.appmesh_role_policy.json
}

resource "aws_iam_role_policy" "datadog_policy" {
  name = "datadog-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}
