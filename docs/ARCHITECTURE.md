# Architecture Documentation

**Project:** Terraform + CI/CD Pipeline  
**Author:** David Onoja  
**Date:** May 2026  
**Status:** Production  

---

## System Overview

A production AWS infrastructure provisioned entirely with Terraform,
with a GitHub Actions CI/CD pipeline that automatically tests, builds,
and deploys a containerized Flask application on every code push.
Zero manual deployment steps after initial setup.

---

## Architecture Diagram

Developer (local machine)
│
│ git push
▼
GitHub (source of truth)
│
│ triggers automatically
▼
GitHub Actions Runner (Ubuntu — GitHub's servers)
│
├── Stage 1: Run 11 unit tests
│   └── STOP if any test fails
│
├── Stage 2: Build Docker image
│   └── Push to AWS ECR (private registry)
│
└── Stage 3: SSH into EC2
│
▼
AWS EC2 (eu-west-1) — 34.252.2.5
│
├── Pull image from ECR (via IAM role)
├── Stop old container
├── Start new container
└── Verify /health returns 200
│
▼
Public Internet

---

## Infrastructure Components

| Resource | Type | Purpose |
|----------|------|---------|
| VPC 10.0.0.0/16 | Networking | Private network — not default AWS VPC |
| Public Subnet 10.0.1.0/24 | Networking | EC2 lives here |
| Internet Gateway | Networking | Connects VPC to internet |
| Route Table | Networking | Routes 0.0.0.0/0 through IGW |
| Security Group | Security | Ports 22, 80, 443 only |
| EC2 t3.micro | Compute | Ubuntu 22.04 — runs the app |
| Elastic IP 34.252.2.5 | Networking | Static IP — never changes |
| ECR Repository | Registry | Private Docker image storage |
| IAM Role (EC2) | Security | EC2 pulls from ECR — no credentials |
| IAM User (pipeline) | Security | GitHub Actions pushes to ECR |
| S3 Bucket | Storage | Terraform remote state |

---

## Security Decisions

| Decision | Reason |
|----------|--------|
| Custom VPC not default | Full control over networking and isolation |
| SSH key-only auth | Passwords are brute-forceable. Keys are not. |
| PermitRootLogin no | Root compromise = total system loss |
| Fail2Ban on SSH | Auto-bans IPs after 3 failed attempts |
| Non-root Docker user | Container compromise gives limited privileges |
| IAM role for EC2 | No credentials on server — temporary tokens only |
| IAM user least privilege | Pipeline can only push to ECR — nothing else |
| Nginx reverse proxy | Flask never directly exposed to internet |
| Security headers | X-Frame-Options, XSS protection, MIME sniffing |
| Rate limiting (10r/s) | Limits DoS impact at proxy layer |
| Remote Terraform state | State file in S3 — never lost, team accessible |

---

## CI/CD Pipeline Stages
Stage 1 — Test (13s):
Runner: GitHub Ubuntu
Action: pip install → pytest
Gate:   ALL tests must pass or pipeline stops
Stage 2 — Build and Push (33s):
Runner: GitHub Ubuntu
Action: docker build → ECR login → docker push
Tag:    git commit hash (full traceability)
Gate:   Image must be in ECR before deploy starts
Stage 3 — Deploy (16s):
Runner: GitHub Ubuntu → SSH into EC2
Action: docker pull → stop old → start new
Gate:   /health must return HTTP 200
Rollback: manual (future: automatic)
Stage 4 — Notify (2s):
Always runs — reports success or failure
Includes: commit hash, author, timing

---

## Deployment Flow
git push main
│
├── Tests pass?
│   NO  → pipeline stops, nothing deployed
│   YES → continue
│
├── Image built and pushed to ECR?
│   NO  → pipeline stops, old version still running
│   YES → continue
│
├── Container started and healthy?
│   NO  → pipeline fails, investigate logs
│   YES → deployment complete
│
└── Total time: ~75 seconds from push to live

---

## Reliability Mechanisms

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Broken code pushed | Tests fail in 13s | Pipeline stops, nothing deployed |
| Bad Docker build | Build stage fails | Deploy never runs |
| Container crash | Docker restart policy | Auto-restart in seconds |
| Health check fails | Deploy stage exits 1 | Alerts in pipeline logs |
| Server reboot | systemd + Docker policy | All services auto-start |

---

## Key Engineering Decisions

**Why Terraform over clicking in AWS console?**
Every resource is code. Version controlled. If the server dies,
`terraform apply` rebuilds identically in 60 seconds. No memory
required. No manual steps. The code IS the documentation.

**Why a custom VPC?**
The default VPC has permissive settings. A custom VPC gives full
control — you define every subnet, route, and gateway explicitly.
You understand what you built because you built every piece.

**Why ECR instead of Docker Hub?**
ECR is private by default. Integrates with IAM natively. Images
stay in the same AWS region as the server — faster pulls. No
public exposure of your application image.

**Why tag images with commit hash?**
`latest` is overwritten on every deploy. Commit hash tags are
permanent. You can always trace which commit is running in
production, and roll back to any previous version by its hash.

**Why separate IAM role and IAM user?**
EC2 is an AWS service — it can assume a role. GitHub Actions
runs on GitHub's servers — it cannot assume a role and needs
permanent credentials. Two different authentication mechanisms
for two different contexts. Both use least privilege.

---

## Debugging Runbook

### Pipeline fails at Deploy to EC2

Check error in pipeline logs
"i/o timeout"       → SSH can't connect → check security group
"Permission denied" → wrong SSH key → check GitHub Secret
"docker: not found" → Docker not installed → check bootstrap
SSH manually and check:
docker ps           → is container running?
docker logs flask-app → what did the app output?
sudo systemctl status nginx → is Nginx up?
curl localhost/health → is app responding?


### App is unreachable from browser

AWS Security Group → port 80 open?
sudo ufw status → UFW allowing port 80?
systemctl status nginx → Nginx running?
docker ps → container running?
curl localhost:5000 → app responding directly?


---

## What I Would Add With More Time

- HTTPS with Let's Encrypt (Certbot) — 10 minutes to add
- Automatic rollback if health check fails
- Prometheus + Grafana metrics dashboard
- Multi-environment (staging → production promotion)
- Terraform modules for reusability
- AWS RDS for database (separate from compute)
- Load balancer + multiple EC2 for high availability
- Slack/email notifications on deployment failure
