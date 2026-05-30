# Terraform + CI/CD Pipeline on AWS

Production AWS infrastructure built entirely with Terraform IaC,
with a GitHub Actions pipeline that automatically tests, builds,
and deploys a containerized Flask app on every push to main.

**Push code → pipeline runs → app is live. Zero manual steps.**

---

## Live Demo

Application running at: `http://34.252.2.5`

Pipeline history: [GitHub Actions](../../actions)

---

## How It Works
git push main
↓
GitHub Actions (automatic):
├── Run 11 unit tests        (stops if any fail)
├── Build Docker image
├── Push to AWS ECR
├── SSH into EC2
├── Deploy new container
└── Verify health check
↓
Live in ~75 seconds

---

## Stack

| Layer | Technology |
|-------|-----------|
| Infrastructure | Terraform + AWS |
| Compute | EC2 t3.micro (Ubuntu 22.04) |
| Networking | Custom VPC, Subnet, IGW, Elastic IP |
| Security | UFW, Fail2Ban, SSH hardening, IAM roles |
| Container | Docker + Gunicorn |
| Web Server | Nginx (reverse proxy) |
| Registry | AWS ECR (private) |
| CI/CD | GitHub Actions |
| App | Python Flask |
| State | Terraform remote state on S3 |

---

## Project Structure
terraform-cicd-pipeline/
├── terraform/
│   ├── providers.tf    # AWS provider + region
│   ├── backend.tf      # Remote state in S3
│   ├── variables.tf    # All configurable values
│   ├── main.tf         # VPC, EC2, ECR, IAM, Elastic IP
│   └── outputs.tf      # Server IP, ECR URL, etc.
├── app/
│   ├── app.py          # Flask application (3 routes)
│   ├── Dockerfile      # Non-root, production-grade
│   ├── requirements.txt
│   └── tests/
│       └── test_app.py # 11 unit tests
├── .github/
│   └── workflows/
│       └── deploy.yml  # Full CI/CD pipeline
└── docs/
└── ARCHITECTURE.md # Full technical documentation

---

## Infrastructure

All AWS resources provisioned by Terraform — nothing clicked
in the console.

```bash
cd terraform
terraform init
terraform plan   # preview changes
terraform apply  # build infrastructure
```

---

## Security Implementation

- SSH key-only authentication (passwords disabled)
- Non-root user inside Docker container
- IAM role for EC2→ECR (no credentials on server)
- IAM user with least privilege for pipeline
- Dual-layer firewall (Security Group + UFW)
- Fail2Ban SSH brute force protection
- Nginx security headers + rate limiting
- All secrets in GitHub Secrets (never in code)

---

## CI/CD Pipeline

Every push to `main` triggers automatically:
test → build → push to ECR → deploy → health check

Failed tests = nothing deploys. Every deployment tagged
with git commit hash for full traceability.

---

## Key Engineering Decisions

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full
explanation of every decision made in this project.

---

## What's Next

- [ ] HTTPS with Let's Encrypt
- [ ] Automatic rollback on failed health check
- [ ] Terraform modules
- [ ] Multi-environment pipeline (staging → prod)
- [ ] Monitoring with Prometheus + Grafana
