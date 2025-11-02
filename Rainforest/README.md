# Hello API - AWS ECS Fargate Deployment

A production-ready, minimal containerized API deployed on AWS ECS Fargate with Infrastructure as Code (Terraform) and automated CI/CD via GitHub Actions.

## Architecture Overview

```
┌─────────────────┐
│  GitHub Actions │
│   (CI/CD)       │
└────────┬────────┘
         │ Push Docker Image
         ▼
┌─────────────────┐
│   Amazon ECR    │
│  (Container     │
│   Registry)     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│           AWS ECS Fargate               │
│  ┌─────────────────────────────────┐   │
│  │    Application Load Balancer    │   │
│  │         (Public HTTP)            │   │
│  └──────────────┬──────────────────┘   │
│                 │                       │
│  ┌──────────────▼──────────────────┐   │
│  │      ECS Service (Fargate)      │   │
│  │  ┌───────────┐  ┌───────────┐  │   │
│  │  │  Task 1   │  │  Task 2   │  │   │
│  │  │ (8080)    │  │ (8080)    │  │   │
│  │  └───────────┘  └───────────┘  │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Key Components:**
- **VPC**: Custom VPC with 2 public subnets across availability zones
- **ALB**: Application Load Balancer for routing HTTP traffic
- **ECS Fargate**: Serverless container orchestration
- **ECR**: Private Docker registry
- **Security Groups**: Least-privilege network access control
- **IAM**: OIDC-based GitHub Actions authentication (no static keys)
- **CloudWatch**: Centralized logging

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 ([Install](https://www.terraform.io/downloads))
3. **AWS CLI** configured ([Install](https://aws.amazon.com/cli/))
4. **Docker** ([Install](https://docs.docker.com/get-docker/))
5. **GitHub Repository** with Actions enabled

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/hello-api.git
cd hello-api
```

### Step 2: Configure Terraform Variables

Edit `terraform/environments/preprod.tfvars` and `terraform/environments/prod.tfvars`:

```hcl
github_org  = "your-github-username"
github_repo = "your-repo-name"
```

### Step 3: Deploy PreProd Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan -var-file="environments/preprod.tfvars"

# Apply infrastructure
terraform apply -var-file="environments/preprod.tfvars"
```

**Important Outputs:**
- `api_endpoint`: Your API URL
- `github_actions_role_arn`: ARN for GitHub Actions
- `ecr_repository_url`: ECR repository URL

### Step 4: Build and Push Initial Image

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ECR_REPOSITORY_URL>

# Build and push
docker build -t <ECR_REPOSITORY_URL>:latest .
docker push <ECR_REPOSITORY_URL>:latest
```

### Step 5: Deploy Prod Infrastructure

```bash
# Apply prod infrastructure
terraform apply -var-file="environments/prod.tfvars"
```

### Step 6: Configure GitHub Secrets

Add these secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

- `AWS_ROLE_ARN`: PreProd GitHub Actions role ARN (from terraform output)
- `AWS_ROLE_ARN_PROD`: Prod GitHub Actions role ARN (from terraform output)

### Step 7: Configure GitHub Environments

1. Go to `Settings > Environments`
2. Create `preprod` environment (no protection rules needed)
3. Create `production` environment:
   - Enable "Required reviewers"
   - Add yourself as a reviewer

## 🏃 Running Locally

### Run with Docker

```bash
# Build the image
docker build -t hello-api:local .

# Run the container
docker run -p 8080:8080 hello-api:local

# Test the endpoint
curl http://localhost:8080/hello
```

Expected response:
```json
{"message": "hello world"}
```

### Run with Python (Development)

```bash
# Install dependencies
pip install -r requirements.txt

# Run the app
python app.py

# Test
curl http://localhost:8080/hello
```

## Deployment Process

### Automated Deployment via Git Tag

1. **Create and push a tag:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **GitHub Actions will automatically:**
   - Build Docker image
   - Tag with version (e.g., `v1.0.0`) and `latest`
   - Push to ECR
   - Deploy to PreProd (automatic)
   - Wait for approval for Production
   - Deploy to Production (after manual approval)

3. **Monitor deployment:**
   - Go to Actions tab in GitHub
   - Watch the workflow progress
   - Approve Production deployment when ready

### Manual Deployment (if needed)

```bash
# Update ECS service to force new deployment
aws ecs update-service \
  --cluster hello-api-preprod-cluster \
  --service hello-api-preprod-service \
  --force-new-deployment \
  --region us-east-1
```

## Testing

### Test PreProd Endpoint

```bash
# Get the endpoint from Terraform output
terraform output api_endpoint

# Test the API
curl http://<ALB_DNS_NAME>/hello
```

Expected response:
```json
{"message": "hello world"}
```

### Test Health Check

```bash
curl http://<ALB_DNS_NAME>/health
```

Expected response:
```json
{"status": "healthy"}
```

### Test Production Endpoint

Same as preprod, but use the prod ALB DNS name from terraform output.

## 🔒 Security Features

### IAM & Authentication
- **GitHub OIDC**: No static AWS credentials stored in GitHub
- **Least-privilege IAM roles**: Separate roles for ECS tasks and GitHub Actions
- **Task roles**: Minimal permissions for running containers

### Network Security
- **Security Groups**: 
  - ALB accepts HTTP from internet (port 80 only)
  - ECS tasks accept traffic only from ALB on port 8080
  - No SSH or unnecessary ports exposed
- **Public subnets**: Tasks use public IPs but protected by security groups
- **VPC isolation**: Dedicated VPC per environment

### Container Security
- **Alpine base image**: Minimal attack surface (~5MB)
- **Non-root user**: Container runs as unprivileged user (uid 1000)
- **Image scanning**: ECR scans on push for vulnerabilities
- **Image lifecycle**: Automatic cleanup of old images (keeps last 10)

### Secrets Management
- No hardcoded credentials in code or Terraform
- GitHub secrets for role ARNs only
- AWS credentials never leave AWS infrastructure

## 📊 Monitoring & Logging

- **CloudWatch Logs**: All container logs centralized
  - Log group: `/ecs/hello-api-{environment}`
  - Retention: 7 days
- **Container Insights**: Enabled on ECS cluster for metrics
- **Health Checks**: 
  - Container-level: `/health` endpoint
  - ALB-level: Target group health checks

View logs:
```bash
aws logs tail /ecs/hello-api-preprod --follow --region us-east-1
```

## Configuration

### Environment Variables

Container configurations are in `terraform/ecs.tf`:
- Port: 8080
- Health check: `/health` endpoint
- CPU/Memory: Configurable per environment via tfvars

### Scaling

Modify in `terraform/environments/{env}.tfvars`:
```hcl
desired_count    = 2  # Number of tasks
container_cpu    = 512
container_memory = 1024
```

Then apply:
```bash
terraform apply -var-file="environments/prod.tfvars"
```

##  Project Structure

```
.
├── app.py                         
├── Dockerfile                     
├── requirements.txt                
├── .github/
│   └── workflows/
│       └── deploy.yml              
├── terraform/
│   ├── main.tf                    
│   ├── variables.tf                
│   ├── outputs.tf                  
│   ├── vpc.tf                      
│   ├── security_groups.tf         
│   ├── alb.tf                      
│   ├── ecr.tf                    
│   ├── iam.tf                    
│   ├── ecs.tf                   
│   └── environments/
│       ├── preprod.tfvars          
│       └── prod.tfvars            
└── README.md                       
```

## CI/CD Pipeline Details

### Workflow Stages

1. **build-and-push**: 
   - Triggered on tag creation
   - Builds Docker image
   - Pushes to PreProd ECR with version tag and `latest`

2. **deploy-preprod**:
   - Automatic deployment
   - Updates ECS service
   - Waits for service stability

3. **deploy-prod**:
   - Requires manual approval (GitHub Environment protection)
   - Copies image from PreProd to Prod ECR
   - Updates Prod ECS service
   - Waits for service stability

### GitHub OIDC Setup

The Terraform creates an OIDC provider that allows GitHub Actions to assume AWS roles without static credentials. The trust relationship is scoped to your specific repository.

##  Cleanup

To destroy all infrastructure:

```bash
# Destroy preprod
cd terraform
terraform destroy -var-file="environments/preprod.tfvars"

# Destroy prod
terraform destroy -var-file="environments/prod.tfvars"
```

**Note**: You may need to manually empty ECR repositories first:
```bash
aws ecr batch-delete-image \
  --repository-name hello-api-preprod \
  --image-ids "$(aws ecr list-images --repository-name hello-api-preprod --query 'imageIds[*]' --output json)" \
  --region us-east-1
```

## 💡 Design Decisions & Trade-offs

### Architecture Choices

1. **ECS Fargate over EC2**
   - No server management
   - Automatic scaling
   - Pay-per-use pricing
   - Slightly higher cost per task vs EC2
   - Less control over underlying infrastructure

2. **Public subnets with security groups**
   - Simpler setup (no NAT gateways)
   - Lower cost (~$30/month savings per NAT)
   - Direct internet access for containers
   - Tasks have public IPs (protected by SGs)
   - **Alternative**: Private subnets + NAT Gateway for stricter isolation

3. **HTTP-only load balancer**
   - Simpler initial setup
   - No TLS/HTTPS
   - **Production recommendation**: Add ACM certificate + HTTPS listener

4. **Separate ECR per environment**
   - Clear environment separation
   - Independent lifecycle policies
   - Images duplicated across environments
   - **Alternative**: Single ECR with environment-specific tags

### Security Considerations

1. **GitHub OIDC over static credentials**
   - No long-lived credentials
   - Automatic credential rotation
   - Scoped to specific repository/branch

2. **Minimal IAM permissions**
   - ECS tasks: Only what's needed to run
   - GitHub Actions: Only ECR and ECS operations
   - Task execution: Only CloudWatch Logs and ECR pulls

3. **Container security**
   - Alpine base (minimal packages)
   - Non-root user
   - No unnecessary tools in image

### What's Missing (Future Improvements)

1. **HTTPS/TLS**
   - Add AWS Certificate Manager (ACM) certificate
   - Update ALB listener to HTTPS
   - Redirect HTTP to HTTPS

2. **Custom Domain**
   - Route53 hosted zone
   - DNS record pointing to ALB
   - Certificate for custom domain

3. **Enhanced Monitoring**
   - CloudWatch dashboards
   - SNS alerts for failures
   - X-Ray tracing

4. **Auto-scaling**
   - ECS Service auto-scaling based on CPU/memory
   - Target tracking policies
   - Scale-in/out cooldowns

5. **Database integration**
   - RDS instance
   - Secrets Manager for credentials
   - Database migrations

6. **Enhanced CI/CD**
   - Integration tests in pipeline
   - Smoke tests post-deployment
   - Automatic rollback on failure
   - Blue-green deployment strategy

7. **Cost optimization**
   - Fargate Spot for non-prod
   - Reserved capacity for prod
   - S3 backend for Terraform state with locking

8. **Disaster Recovery**
   - Multi-region deployment
   - Automated backups
   - RTO/RPO definitions

9. **Compliance**
   - AWS Config rules
   - GuardDuty for threat detection
   - VPC Flow Logs
   - CloudTrail for audit logging

## Troubleshooting

### ECS Service won't stabilize

```bash
# Check service events
aws ecs describe-services \
  --cluster hello-api-preprod-cluster \
  --services hello-api-preprod-service \
  --region us-east-1

# Check task logs
aws logs tail /ecs/hello-api-preprod --follow --region us-east-1
```

### GitHub Actions fails to authenticate

1. Verify OIDC provider exists in IAM
2. Check role ARN in GitHub secrets
3. Verify trust relationship includes your repository

### Container fails health checks

```bash
# Check container logs
aws logs tail /ecs/hello-api-preprod --follow --region us-east-1

# Test locally
docker run -p 8080:8080 <ECR_URL>:latest
curl http://localhost:8080/health
```

### Terraform state issues

If using local state and working in a team, consider:
```bash
# Setup S3 backend
terraform init -backend-config="bucket=your-state-bucket"
```

## Additional Resources

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## Assumptions

1. Using AWS us-east-1 region (easily changeable)
2. No existing VPCs or networking conflicts
3. AWS CLI configured with appropriate permissions
4. GitHub repository allows Actions and Environments
5. Initial image pushed manually before first ECS deployment
6. Cost considerations favoring simplicity over redundancy for demo

##  License

MIT License - feel free to use this as a template for your projects.

## Author

Built as a production-ready reference implementation for containerized API deployments on AWS.

---

**Estimated AWS Costs** (us-east-1):
- PreProd: ~$15-20/month
- Prod: ~$30-40/month
- Includes: Fargate, ALB, ECR, CloudWatch Logs, Data Transfer

*Costs vary based on traffic and usage patterns*