# Infrastructure Engineering Challenge — Marco Liao
Demonstrate skills and approach to Infrastructure Engineering

**Repository:** https://github.com/marcolw/infra_engineer_challenge.git  
**Domain:** infra.xeniumsolution.space

## Highlights

-  Infrastructure as Code (IaC): Terraform to provision EC2, networking, and IAM (OIDC) resources.
-  Remote State Management: Terraform backend with state locking for production.
-  Secure Secrets Management: SSH key stored in AWS Secrets Manager — no secrets in repo.
-  Ephemeral Credentials: GitHub OIDC with IAM role for short-lived AWS credentials (no long-lived keys).
-  Automated TLS: Certbot for HTTPS provisioning and renewal.
-  CI/CD Pipeline: Automated pipelines for provisioning and website deployment to AWS account.
-  Ongoing Deployment: Push-to-deploy workflow for updating website content.

## What this repo contains
- `site/`: Static site source. The home page displays: **"This is Marco Liao's website"**.
- `infra`: Terraform scripts to provision AWS resources.
- `scripts/`: Utility scripts for boostrapping(terraform), cleanup and certbot for TLS cert.
- `.github/workflows/`: GitHub Actions workflows for building infrastructure and deploying the site.

## How to reproduce
1. Clone repo: git clone https://github.com/marcolw/infra_engineer_challenge.git
2. Authenticate with AWS (SSO or temporary Access Keys).
3. Bootstrap Terraform backend & OIDC:
   - Run: scripts/bootstrap.sh. (update $BUCKET in the script with random bucket name)
   - Trigger "Terraform Build" GHA pipeline to provision EC2,Networking and assolicate objects for website.
   - Retrieve Public IP from Terraform output, update your DNS A record (e.g., demo domain:infra.xeniumsolution.space).
   - Once A record propagates, run scripts/run-certbot.sh against EC2 instance to enable https.
4. Access infra.xeniumsolution.space or your domain name for verification.
5. Update Website contents:
   - Update files in site/ folders, Commit & Push to remote main branch.
   - Trigger "Deploy Site to EC2" GHA pipeline to sync contents to EC2 nginx webserver.
   - Refresh website for verification (infra.xeniumsolution.space)
6. Clean up:
   - Trigger "Terraform Destroy" pipeline to remove infrastructure resources, providing your target AWS account ID.
   - Run local cneanup: scripts/cleanup.sh to remove bootstrapped resources。

## What else I would do with more time
- Integrate ACM + Route53 for simpler HTTPS + DNS automation.
- Add security scans in pipelines (e.g., tfsec for IaC, ShellCheck for Bashshell, HTMLHint for static).
- Provision monitoring resources(CloudWatch) via Terraform.
- Apply least privilege to GitHub Actions OIDC IAM role.

## Alternative solutions consideration
- EC2 Auto Scaling + ALB for high availability (trade-off: higher cost, more setup).
- CloudFront + S3 for scalable static site hosting. (Scalability)

## Production-ready enhancement
- Modularize Terraform with values file for multiple environments.
- Containerize multi layer and deploy to EKS behind ALB (supports dynamic workload).
- Adopt GitFlow branching strategy for collaborative environment: branch protection, approval gate and automated tests.
- Observability: Prometheus(metric), Grafana, Tempo (traces), logging (Loki/ELK).