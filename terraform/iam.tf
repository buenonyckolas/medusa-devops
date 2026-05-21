# ============================================================
# IAM — ECS Task Execution Role
# Used by the ECS agent to pull images from ECR and send
# logs to CloudWatch on behalf of the task.
# ============================================================

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the AWS-managed policy that covers ECR pull + CloudWatch Logs write
resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Grant the execution role permission to read secrets from Secrets Manager,
# so ECS can inject them as environment variables at task startup
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.project_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_secretsmanager_secret.medusa_secrets.arn
        ]
      }
    ]
  })
}

# ============================================================
# IAM — ECS Task Role
# Attached to the running container; grants app-level AWS access.
# Extend this with additional policies as the app needs them
# (e.g., S3 for file uploads, SES for email).
# ============================================================

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# ============================================================
# IAM — EC2 Instance Role
# Allows EC2 container instances to register with the ECS
# cluster and send metrics/logs to CloudWatch.
# ============================================================

resource "aws_iam_role" "ec2_instance" {
  name = "${var.project_name}-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecs" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  # SSM Session Manager allows SSH-less shell access to EC2 instances
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile wraps the role so EC2 can assume it
resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance.name
}
