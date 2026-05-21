# ============================================================
# ECR Repositories
# Stores Docker images built by the CI/CD pipeline.
# The CI pipeline should push here instead of GHCR for AWS deployments.
# ============================================================

resource "aws_ecr_repository" "medusa" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    # Automatically scan images for vulnerabilities on push
    scan_on_push = true
  }

  tags = { Name = "${var.project_name}-backend-ecr" }
}

resource "aws_ecr_repository" "nginx" {
  name                 = "${var.project_name}-nginx"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.project_name}-nginx-ecr" }
}

# ============================================================
# Lifecycle Policy — keep only the last 10 tagged images
# to control storage costs
# ============================================================

resource "aws_ecr_lifecycle_policy" "medusa" {
  repository = aws_ecr_repository.medusa.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the 10 most recent tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["sha-"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "nginx" {
  repository = aws_ecr_repository.nginx.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the 10 most recent tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}
