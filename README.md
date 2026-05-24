# Terraform + CI/CD Pipeline on AWS

Production AWS infrastructure provisioned entirely with Terraform, 
with a GitHub Actions CI/CD pipeline that automatically builds and 
deploys a containerized Flask application on every code push.

---

## What This Project Builds
Developer pushes code
↓
GitHub Actions triggers automatically
↓
├── Runs Python tests
├── Builds Docker image
├── Pushes image to AWS ECR
├── SSHes into EC2
├── Deploys new container
└── Verifies health check
↓
App is live. Zero manual steps.

---

## Infrastructure (Terraform)

All AWS resources are defined as code. Nothing was clicked in the console.

| Resource | Purpose |
|----------|---------|
| VPC (10.0.0.0/16) | Private network — isolated from default AWS networking |
| Public Subnet | Where the EC2 lives — internet accessible |
| Internet Gateway | Connects the VPC to the public internet |
| Route Table | Routes internet-bound traffic through the IGW |
| Security Group | Firewall — SSH restricted to my IP, HTTP/S public |
| EC2 (t3.micro) | Ubuntu 22.04 server running Docker + Nginx |
| ECR Repository | Private Docker image registry |
| S3 Bucket | Remote Terraform state storage |

---

## CI/CD Pipeline (GitHub Actions)

Every push to `main` triggers the full pipeline automatically.
Stage 1 — Test:    Python unit tests must pass
Stage 2 — Build:   Docker image built and tagged with commit hash
Stage 3 — Push:    Image pushed to AWS ECR
Stage 4 — Deploy:  EC2 pulls new image, restarts container
Stage 5 — Verify:  Health check confirms app is live

If any stage fails — pipeline stops. Bad code never reaches production.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Infrastructure | Terraform + AWS |
| Compute | AWS EC2 (Ubuntu 22.04) |
| Networking | Custom VPC, Subnet, IGW, Route Table |
| Container Runtime | Docker + Gunicorn |
| Web Server | Nginx (reverse proxy) |
| Image Registry | AWS ECR |
| CI/CD | GitHub Actions |
| Application | Python Flask |
| State Management | Terraform remote state on S3 |

---

## Project Structure
terraform-cicd-pipeline/
├── terraform/
│   ├── providers.tf      # AWS provider configuration
│   ├── backend.tf        # Remote state in S3
│   ├── variables.tf      # All configurable values
│   ├── main.tf           # Core infrastructure resources
│   └── outputs.tf        # Values printed after apply
├── app/
│   ├── app.py            # Flask application
│   ├── Dockerfile        # Container definition
│   ├── requirements.txt  # Python dependencies
│   └── tests/
│       └── test_app.py   # Unit tests (run by CI pipeline)
├── .github/
│   └── workflows/
│       └── deploy.yml    # CI/CD pipeline definition
└── .gitignore

---

## How to Use

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- AWS account with appropriate permissions

### Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform and connect to S3 backend
terraform init

# Preview what will be built
terraform plan

# Build the infrastructure
terraform apply
```

### Destroy Infrastructure (cost control)

```bash
terraform destroy
```

---

## Key Engineering Decisions

**Why Terraform over clicking in AWS console?**
Infrastructure as code means every resource is documented, version controlled, and reproducible. If the server dies, `terraform apply` rebuilds it identically in 60 seconds.

**Why a custom VPC instead of the default?**
The default VPC has permissive settings not suitable for production. A custom VPC gives full control over networking, routing, and isolation.

**Why ECR instead of Docker Hub?**
ECR is private by default, integrates natively with AWS IAM for authentication, and keeps images in the same region as the server — faster pulls, no public exposure.

**Why tag every resource?**
With many resources in AWS, tags are the only way to know what belongs to what project, who manages it, and what environment it's in. Every resource here is tagged with Project, Environment, and ManagedBy=terraform.

---

## What I'm Building Next

- [ ] IAM role for EC2 → ECR authentication (no hardcoded credentials)
- [ ] Nginx configuration via Terraform user_data
- [ ] Flask app with unit tests
- [ ] GitHub Actions workflow (full CI/CD pipeline)
- [ ] HTTPS with Let's Encrypt
