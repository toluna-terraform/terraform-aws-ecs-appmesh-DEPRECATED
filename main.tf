resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.app_name}-${var.environment}"
}

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
  mesh_name  = "${var.environment}"
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
  mesh_name  = "${var.environment}"
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
  mesh_name           = "${var.environment}"
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

resource "aws_appmesh_virtual_node" "td_net" {
  for_each   = toset(["blue", "green"])
  name       = "vn-${var.app_name}-${var.environment}-${each.key}"
  mesh_name  = var.app_mesh_name
  mesh_owner = "${var.app_mesh_owner}"
  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = var.environment
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
  for_each = toset(["blue","green"])
  family                   = "${var.app_name}-${var.environment}-${each.key}"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  container_definitions    = data.template_file.default-container[each.key].rendered
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


resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "role-ecs-${var.app_name}-${var.environment}"
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
  name = "policy-appmesh-${var.app_name}-${var.environment}-${var.env_type}"
  role = aws_iam_role.ecs_task_execution_role.name
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



# // ECS security group
resource "aws_security_group" "ecs_sg" {
  name   = "${var.environment}-${var.app_name}-ecs"
  vpc_id = var.vpc_id

  tags = {
    Name = "sg-${var.environment}-${var.app_name}-ecs"
  }
}

resource "aws_security_group_rule" "ecs_sg" {
  for_each = { for k, v in merge(local.ecs_security_group_rules, var.ecs_security_group_additional_rules) : k => v }

  # Required
  security_group_id = aws_security_group.ecs_sg.id
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type

  # Optional
  description              = try(each.value.description, null)
  cidr_blocks              = try(each.value.cidr_blocks, null)
  ipv6_cidr_blocks         = try(each.value.ipv6_cidr_blocks, null)
  prefix_list_ids          = try(each.value.prefix_list_ids, [])
  self                     = try(each.value.self, null)
  source_security_group_id = try(each.value.source_security_group_id, null)

}
