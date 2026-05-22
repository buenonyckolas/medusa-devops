# Medusa E-Commerce DevOps

A production-grade DevOps showcase built around [Medusa v2](https://medusajs.com/) — an open-source e-commerce platform. This repository demonstrates a full infrastructure stack: local development with Docker Compose, observability with Prometheus and Grafana, container orchestration with Kubernetes, automated CI/CD with GitHub Actions, and cloud infrastructure-as-code with Terraform on AWS.

## Architecture overview

```
┌─────────────────────────────────────────────────────────┐
│                     Local / Dev                         │
│  Nginx (80) → Medusa API (9000) → PostgreSQL + Redis    │
└─────────────────────────────────────────────────────────┘
              ↓ docker-compose.monitoring.yml
┌─────────────────────────────────────────────────────────┐
│                   Observability                         │
│         Prometheus (9090) + Grafana (3000)              │
└─────────────────────────────────────────────────────────┘
              ↓ k8s/base/
┌─────────────────────────────────────────────────────────┐
│                   Kubernetes                            │
│     Namespace → Secrets → PostgreSQL → Redis → Medusa  │
└─────────────────────────────────────────────────────────┘
              ↓ .github/workflows/ci.yml
┌─────────────────────────────────────────────────────────┐
│                    CI/CD                                │
│         Test → Build → Push to ECR → Deploy ECS        │
└─────────────────────────────────────────────────────────┘
              ↓ terraform/
┌─────────────────────────────────────────────────────────┐
│              AWS Infrastructure (IaC)                   │
│  VPC → ECS (EC2) → RDS → ALB → ECR → Secrets Manager  │
└─────────────────────────────────────────────────────────┘
```

## Repository structure

```
.
├── backend/                  # Medusa v2 Node.js application
├── backend-storefront/       # Next.js storefront
├── nginx/                    # Nginx reverse proxy config
├── monitoring/               # Prometheus and Grafana config
│   └── prometheus/
│   └── grafana/
├── k8s/base/                 # Kubernetes manifests
├── terraform/                # AWS infrastructure (IaC)
│   ├── main.tf
│   ├── vpc.tf
│   ├── ecs.tf
│   ├── rds.tf
│   ├── alb.tf
│   ├── ecr.tf
│   ├── iam.tf
│   ├── secrets.tf
│   ├── variables.tf
│   └── outputs.tf
└── .github/workflows/ci.yml  # GitHub Actions pipeline
```

---

## 1. Local development with Docker Compose

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) 24+
- [Docker Compose](https://docs.docker.com/compose/install/) v2

### Setup

```bash
# Copy and fill in the environment variables
cp .env.example .env
```

Edit `.env`:

```env
POSTGRES_USER=medusa
POSTGRES_PASSWORD=your_password
POSTGRES_DB=medusa
JWT_SECRET=your_jwt_secret
COOKIE_SECRET=your_cookie_secret
NODE_ENV=development
```

### Running

```bash
# Start all services (Nginx, Medusa, PostgreSQL, Redis)
docker compose up -d

# Check logs
docker compose logs -f medusa

# Stop
docker compose down
```

| Service | URL |
|---|---|
| Medusa API | http://localhost/health |
| Medusa Admin | http://localhost/app |

---

## 2. Monitoring (Prometheus + Grafana)

### Prerequisites

- Docker Compose running (section 1)

### Running

```bash
docker compose -f docker-compose.monitoring.yml up -d
```

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |

Grafana is pre-configured with Prometheus as the default datasource.

### Stopping

```bash
docker compose -f docker-compose.monitoring.yml down
```

---

## 3. Kubernetes

### Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured against a running cluster
- A Kubernetes cluster (e.g. [kind](https://kind.sigs.k8s.io/), [minikube](https://minikube.sigs.k8s.io/), or a managed cluster)

### Setup secrets

```bash
# Copy the secrets example and fill in your values
cp k8s/base/secrets.example.yml k8s/base/secrets.yml
```

Edit `k8s/base/secrets.yml` with your base64-encoded values:

```bash
# Encode a value
echo -n "your_value" | base64
```

### Deploying

```bash
# Apply all manifests in order
kubectl apply -f k8s/base/namespace.yml
kubectl apply -f k8s/base/secrets.yml
kubectl apply -f k8s/base/postgres.yml
kubectl apply -f k8s/base/redis.yml
kubectl apply -f k8s/base/medusa.yml

# Check pod status
kubectl get pods -n medusa
```

### Removing

```bash
kubectl delete namespace medusa
```

---

## 4. CI/CD with GitHub Actions

The pipeline defined in `.github/workflows/ci.yml` runs on every push to `main`.

### Pipeline stages

| Stage | Trigger | Description |
|---|---|---|
| **Test** | All pushes and PRs | Installs dependencies and validates the build |
| **Build & Push** | Push to `main` only | Builds the Docker image and pushes to AWS ECR |
| **Deploy** | After successful build | Forces a new ECS deployment and waits for stability |

### Required GitHub secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key with ECR and ECS permissions |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

### Required GitHub environment

The deploy stage uses a `production` environment. Create it at **Settings → Environments → New environment** and name it `production`.

---

## 5. AWS Infrastructure with Terraform

> **Note:** This infrastructure costs approximately $70–100/month when running (NAT Gateway, ALB, RDS, EC2). It is intended as a reference implementation and showcase of infrastructure-as-code practices — not for permanent deployment.

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials
- An AWS account with sufficient permissions

### Bootstrap remote state (one-time)

The Terraform state is stored remotely. Create the required AWS resources before the first `apply`:

```bash
# Create the S3 bucket for state storage
aws s3api create-bucket --bucket medusa-terraform-state-bnyck --region us-east-1
aws s3api put-bucket-versioning --bucket medusa-terraform-state-bnyck \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket medusa-terraform-state-bnyck \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create the DynamoDB table for state locking
aws dynamodb create-table \
  --table-name medusa-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Deploying

```bash
cd terraform

terraform init

# Sensitive variables — never commit these
terraform plan \
  -var="jwt_secret=your_jwt_secret" \
  -var="cookie_secret=your_cookie_secret" \
  -var="db_password=your_db_password"

terraform apply \
  -var="jwt_secret=your_jwt_secret" \
  -var="cookie_secret=your_cookie_secret" \
  -var="db_password=your_db_password"
```

### Key outputs after apply

```bash
terraform output alb_dns_name     # Public URL of the load balancer
terraform output ecr_medusa_url   # ECR repository URL for CI/CD
terraform output ecs_cluster_name
terraform output ecs_service_name
```

### Destroying

```bash
terraform destroy \
  -var="jwt_secret=any" \
  -var="cookie_secret=any" \
  -var="db_password=any"
```

### Infrastructure components

| Component | Resource | Details |
|---|---|---|
| Networking | VPC, subnets, IGW, NAT Gateways | 2 public + 2 private subnets across 2 AZs |
| Compute | ECS on EC2 + Auto Scaling Group | t3.medium, 1–3 instances |
| Database | RDS PostgreSQL 15 | db.t3.micro, encrypted, 7-day backup |
| Load balancer | ALB | HTTP listener, health checks |
| Registry | ECR | medusa-backend + medusa-nginx repositories |
| Secrets | Secrets Manager | DATABASE_URL, JWT_SECRET, COOKIE_SECRET |
| Observability | CloudWatch | Container logs, 30-day retention |

---

## Tech stack

| Layer | Technology |
|---|---|
| Application | Medusa v2.13.1, Node.js 20, TypeScript |
| Storefront | Next.js |
| Database | PostgreSQL 15 |
| Cache | Redis 7 |
| Proxy | Nginx |
| Containers | Docker, Docker Compose |
| Orchestration | Kubernetes |
| CI/CD | GitHub Actions |
| Registry | AWS ECR |
| Cloud | AWS (ECS, RDS, ALB, VPC, Secrets Manager) |
| IaC | Terraform >= 1.6 |
| Monitoring | Prometheus, Grafana |
