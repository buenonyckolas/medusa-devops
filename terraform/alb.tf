# ============================================================
# Application Load Balancer
# Sits in public subnets and forwards HTTP traffic to ECS tasks
# in private subnets.
# ============================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Enable access logs for auditing and troubleshooting (optional bucket required)
  # access_logs {
  #   bucket  = "my-alb-logs-bucket"
  #   prefix  = var.project_name
  #   enabled = true
  # }

  tags = { Name = "${var.project_name}-alb" }
}

# ============================================================
# Target Group — Medusa backend (port 9000)
# ============================================================

resource "aws_lb_target_group" "medusa" {
  name        = "${var.project_name}-tg"
  port        = var.medusa_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # EC2 instances running ECS tasks

  health_check {
    enabled             = true
    path                = "/health"       # Medusa exposes this endpoint by default
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Allow in-flight requests to complete before deregistering instances
  deregistration_delay = 30

  tags = { Name = "${var.project_name}-tg" }
}

# ============================================================
# Listeners
# ============================================================

# HTTP listener — forwards all traffic to the Medusa target group
# For production, replace this with an HTTPS listener and add an
# HTTP → HTTPS redirect listener on port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.medusa.arn
  }
}

# ============================================================
# HTTPS Listener (commented out — enable after adding an ACM certificate)
# ============================================================

# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.acm_certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.medusa.arn
#   }
# }
#
# resource "aws_lb_listener" "http_redirect" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 80
#   protocol          = "HTTP"
#
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }
