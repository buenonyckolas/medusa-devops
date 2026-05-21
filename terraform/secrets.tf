# ============================================================
# AWS Secrets Manager
# Stores sensitive configuration values that ECS injects into
# containers at startup via the "secrets" field in the task definition.
# ============================================================

resource "aws_secretsmanager_secret" "medusa_secrets" {
  name                    = "${var.project_name}/${var.environment}/app-secrets"
  description             = "Application secrets for the Medusa e-commerce backend"
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-app-secrets" }
}

resource "aws_secretsmanager_secret_version" "medusa_secrets" {
  secret_id = aws_secretsmanager_secret.medusa_secrets.id

  secret_string = jsonencode({
    DATABASE_URL  = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
    JWT_SECRET    = var.jwt_secret
    COOKIE_SECRET = var.cookie_secret
  })

  # Recreate the version whenever the DB endpoint or credentials change
  depends_on = [aws_db_instance.postgres]
}
