
locals {
  app_env          = data.terraform_remote_state.common.outputs.app_env
  app_environment  = data.terraform_remote_state.common.outputs.app_environment
  app_name_and_env = "${var.app_name}-${local.app_env}"
  name_tag_suffix  = "${var.app_name}-${var.customer}-${local.app_environment}"
}

/*
 * Create target group for ALB
 */
resource "aws_alb_target_group" "one" {
  name                 = substr("tg-${local.app_name_and_env}", 0, 32)
  protocol             = "HTTPS"
  port                 = local.api_https_port
  vpc_id               = data.terraform_remote_state.common.outputs.vpc_id
  deregistration_delay = "30"

  health_check {
    path                = "/heartbeat"
    matcher             = "200"
    protocol            = "HTTP"
    port                = local.api_http_port
    timeout             = 4 # seconds
    interval            = 5 # seconds
    healthy_threshold   = 2 # count
    unhealthy_threshold = 2 # count
  }

  tags = {
    name = "alb_target_group-${local.name_tag_suffix}"
  }
}

/*
 * Create listener rule for hostname routing to new target group
 */
resource "aws_alb_listener_rule" "one" {
  listener_arn = data.terraform_remote_state.common.outputs.alb_https_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.one.arn
  }

  condition {
    host_header {
      values = [cloudflare_record.cname.hostname]
    }
  }

  tags = {
    name = "alb_listener_rule-${local.name_tag_suffix}"
  }
}

/*
 * Create cloudwatch log group for app logs
 */
resource "aws_cloudwatch_log_group" "one" {
  name              = local.app_name_and_env
  retention_in_days = 30

  tags = {
    name = "cloudwatch_log_group-${local.name_tag_suffix}"
  }
}

/*
 * Create container definition for the service
 */
locals {
  api_container_name = "${var.app_name}-api"
  api_http_port      = "8080"
  api_https_port     = "8443"

  task_def = jsonencode(
    [
      {
        name   = local.api_container_name,
        image  = "1password/connect-api:latest",
        cpu    = var.api_cpu,
        memory = var.api_memory,
        logConfiguration = {
          logDriver = "awslogs",
          options = {
            awslogs-group         = aws_cloudwatch_log_group.one.name,
            awslogs-region        = var.aws_region,
            awslogs-stream-prefix = "${var.app_name}-api-${local.app_env}"
          }
        },
        portMappings = [
          {
            containerPort = tonumber(local.api_http_port)
            hostPort      = tonumber(local.api_http_port)
          },
          {
            containerPort = tonumber(local.api_https_port)
            hostPort      = tonumber(local.api_https_port)
          },
        ],
        mountPoints = [
          {
            sourceVolume  = "connect-data"
            containerPath = "/home/opuser/.op/data"
          }
        ]
        environment = [
          {
            name  = "OP_SESSION",
            value = var.onepassword_credentials,
          },
          {
            name  = "OP_HTTP_PORT"
            value = local.api_http_port
          },
          {
            name  = "OP_HTTPS_PORT"
            value = local.api_https_port
          },
          {
            name  = "OP_LOG_LEVEL"
            value = var.log_level
          },
          {
            name = "OP_TLS_KEY_FILE"
            value = tls_private_key.edd25519.private_key_pem
          },
          {
            name = "OP_TLS_CERT_FILE"
            value = tls_self_signed_cert.one.cert_pem
          }
        ]
      },
      {
        name   = "${var.app_name}-sync"
        image  = "1password/connect-sync:latest"
        cpu    = var.sync_cpu
        memory = var.sync_memory
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.one.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "${var.app_name}-sync-${local.app_env}"
          }
        }
        mountPoints = [
          {
            sourceVolume  = "connect-data"
            containerPath = "/home/opuser/.op/data"
          }
        ]
        environment = [
          {
            name  = "OP_SESSION"
            value = var.onepassword_credentials,
          },
          {
            name  = "OP_HTTP_PORT"
            value = "8081"
          },
          {
            name  = "OP_LOG_LEVEL"
            value = var.log_level
          },
        ]
      }
    ]
  )
}

/*
 * Create new ecs service for the connect-api container
 */
module "ecs_api" {
  source             = "github.com/silinternational/terraform-modules//aws/ecs/service-only?ref=8.0.1"
  cluster_id         = data.terraform_remote_state.common.outputs.ecs_cluster_id
  service_name       = var.app_name
  service_env        = local.app_env
  container_def_json = local.task_def
  desired_count      = var.desired_count
  tg_arn             = aws_alb_target_group.one.arn
  lb_container_name  = local.api_container_name
  lb_container_port  = tonumber(local.api_http_port)
  ecsServiceRole_arn = data.terraform_remote_state.common.outputs.ecsServiceRole_arn
  volumes = [
    {
      name = "connect-data"
    },
  ]
}

/*
 * Create Cloudflare DNS record
 */
resource "cloudflare_record" "cname" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = var.subdomain
  value   = data.terraform_remote_state.common.outputs.alb_dns_name
  type    = "CNAME"
  proxied = true
}

data "cloudflare_zones" "domain" {
  filter {
    name        = var.cloudflare_domain
    lookup_type = "exact"
    status      = "active"
  }
}

resource "tls_self_signed_cert" "one" {
  private_key_pem = tls_private_key.edd25519.private_key_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["localhost"]
}

resource "tls_private_key" "edd25519" {
  algorithm   = "ED25519"
}
