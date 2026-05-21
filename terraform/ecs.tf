# ============================================================
# ECS Cluster
# ============================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # Enables CloudWatch Container Insights for cluster-level metrics
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# ============================================================
# EC2 Launch Template — ECS-optimised AMI
# ============================================================

# Fetch the latest ECS-optimised Amazon Linux 2 AMI for the selected region
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ec2_instance_type

  # Associate an SSH key pair only when one is provided
  key_name = var.ec2_key_pair_name != "" ? var.ec2_key_pair_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance.name
  }

  network_interfaces {
    associate_public_ip_address = false # Instances live in private subnets
    security_groups             = [aws_security_group.ecs.id]
    delete_on_termination       = true
  }

  # Register the EC2 instance with our ECS cluster on boot
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30  # GiB — enough for several container images
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-ecs-instance"
      Project = var.project_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================
# Auto Scaling Group — manages EC2 capacity for the ECS cluster
# ============================================================

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = var.ec2_min_size
  max_size            = var.ec2_max_size
  desired_capacity    = var.ec2_desired_capacity

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  # Protect instances from scale-in while they are draining ECS tasks
  protect_from_scale_in = true

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 # Keep at least 50% of instances healthy during refresh
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Link the ASG to the ECS cluster so ECS can manage capacity automatically
resource "aws_ecs_capacity_provider" "ec2" {
  name = "${var.project_name}-ec2-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80 # Keep EC2 instances at 80% capacity utilisation
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ec2.name
  }
}

# ============================================================
# CloudWatch Log Group — receives container stdout/stderr
# ============================================================

resource "aws_cloudwatch_log_group" "medusa" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30

  tags = { Name = "${var.project_name}-logs" }
}

# ============================================================
# ECS Task Definition — Medusa backend
# ============================================================

resource "aws_ecs_task_definition" "medusa" {
  family                   = "${var.project_name}-backend"
  network_mode             = "bridge"      # Required when running on EC2 (not Fargate)
  requires_compatibilities = ["EC2"]
  cpu                      = var.medusa_cpu
  memory                   = var.medusa_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "medusa"
      image     = "${aws_ecr_repository.medusa.repository_url}:latest"
      essential = true
      cpu       = var.medusa_cpu
      memory    = var.medusa_memory

      portMappings = [
        {
          containerPort = var.medusa_container_port
          hostPort      = 0             # Dynamically assigned host port (bridge networking)
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = tostring(var.medusa_container_port)
        }
      ]

      # Secrets are fetched from Secrets Manager and injected as environment variables
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${aws_secretsmanager_secret.medusa_secrets.arn}:DATABASE_URL::"
        },
        {
          name      = "JWT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.medusa_secrets.arn}:JWT_SECRET::"
        },
        {
          name      = "COOKIE_SECRET"
          valueFrom = "${aws_secretsmanager_secret.medusa_secrets.arn}:COOKIE_SECRET::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.medusa.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "medusa"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.medusa_container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60 # Give the app time to run DB migrations before health checks start
      }
    }
  ])

  tags = { Name = "${var.project_name}-task-definition" }
}

# ============================================================
# ECS Service — keeps the desired number of Medusa tasks running
# ============================================================

resource "aws_ecs_service" "medusa" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.medusa.arn
  desired_count   = var.medusa_desired_count

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    base              = 1
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.medusa.arn
    container_name   = "medusa"
    container_port   = var.medusa_container_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true # Automatically rollback if the deployment fails
  }

  # Spread tasks across AZs for fault tolerance
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution_managed
  ]

  # Ignore task_definition changes so CI/CD deployments (new image tags)
  # do not cause Terraform to replace the service
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = { Name = "${var.project_name}-ecs-service" }
}
