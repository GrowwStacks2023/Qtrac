# BriskLearning Complete Deployment Guide

## Overview
This guide will deploy a complete data processing infrastructure for BriskLearning with:
- Environment-specific subdomains (dev/test/prod.brisklearning.com)
- Automatic SSL certificates via Caddy
- Integration with existing PostgreSQL server (scannedfiles.postgres.database.azure.com)
- File processing with virus scanning and AI embeddings
- n8n workflow automation

## Prerequisites

### 1. Domain Configuration
**Configure DNS records for brisklearning.com BEFORE deployment:**

```dns
# After getting VM IP from terraform output, create these A records:
dev.brisklearning.com      → YOUR_VM_IP
test.brisklearning.com     → YOUR_VM_IP  
prod.brisklearning.com     → YOUR_VM_IP
n8n.dev.brisklearning.com  → YOUR_VM_IP
n8n.test.brisklearning.com → YOUR_VM_IP
n8n.prod.brisklearning.com → YOUR_VM_IP
api.dev.brisklearning.com  → YOUR_VM_IP
api.test.brisklearning.com → YOUR_VM_IP
api.prod.brisklearning.com → YOUR_VM_IP
```

### 2. Azure Setup
```bash
# Install Azure CLI and Terraform
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Login to Azure
az login

# Create service principal (use PowerShell to avoid path issues)
az ad sp create-for-rbac --name "brisklearning-terraform-sp" --role "Contributor" --scopes "/subscriptions/0c8d18ae-4640-4da5-9ca9-6684d674951a"
```

### 3. Set Environment Variables
```bash
export ARM_CLIENT_ID="your-app-id"
export ARM_CLIENT_SECRET="your-password"  
export ARM_SUBSCRIPTION_ID="0c8d18ae-4640-4da5-9ca9-6684d674951a"
export ARM_TENANT_ID="f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
```

## Step-by-Step Deployment

### Step 1: Project Structure
Create the following directory structure:
```
brisklearning-infrastructure/
├── terraform/
│   └── environments/
│       ├── dev/
│       │   └── terraform.tfvars
│       ├── test/
│       │   └── terraform.tfvars
│       └── prod/
│           └── terraform.tfvars
├── main.tf
├── variables.tf
├── outputs.tf
├── cloud-init.yml
└── file-processor/
    ├── file_processor.py
    └── requirements.txt
```

### Step 2: Environment Configuration Files
Use the terraform.tfvars files provided for each environment (dev, test, prod).

**SECURITY NOTE**: In production, move the postgres password to Key Vault:
```bash
az keyvault secret set --vault-name "brisklearning-dev-kv" --name "postgres-password" --value "palash2003@"
```

### Step 3: Deploy Infrastructure

**For Development Environment:**
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Get the VM IP
VM_IP=$(terraform output -raw vm_public_ip)
echo "VM IP: $VM_IP"
```

**For Test Environment:**
```bash
cd ../test
terraform init
terraform plan
terraform apply
```

**For Production Environment:**
```bash
cd ../prod
terraform init
terraform plan
terraform apply
```

### Step 4: Configure DNS Records
After getting the VM IP, configure your DNS:
```bash
# Replace YOUR_VM_IP with the actual IP from terraform output
# Configure these in your domain registrar's DNS management:
dev.brisklearning.com → YOUR_VM_IP
n8n.dev.brisklearning.com → YOUR_VM_IP
api.dev.brisklearning.com → YOUR_VM_IP
```

### Step 5: Verify Deployment
```bash
# Get SSH key and connect
az keyvault secret show --vault-name brisklearning-dev-kv --name vm-ssh-private-key --query value -o tsv > ~/.ssh/vm_key
chmod 600 ~/.ssh/vm_key
ssh -i ~/.ssh/vm_key azureuser@$VM_IP

# Check services
docker ps
docker-compose logs -f
```

### Step 6: Test Services
```bash
# Test health endpoint
curl http://$VM_IP:8080/health

# Test HTTPS (wait 5-10 minutes for SSL certificates)
curl -I https://dev.brisklearning.com/health

# Test n8n access
curl -I https://n8n.dev.brisklearning.com
```

## Service Access Points

### Development Environment:
- **Main Site**: https://dev.brisklearning.com
- **n8n Interface**: https://n8n.dev.brisklearning.com (admin / BriskLearning2024!)
- **API Webhooks**: https://api.dev.brisklearning.com/webhook/
- **Health Check**: http://VM_IP:8080/health

### Test Environment:
- **Main Site**: https://test.brisklearning.com  
- **n8n Interface**: https://n8n.test.brisklearning.com
- **API Webhooks**: https://api.test.brisklearning.com/webhook/

### Production Environment:
- **Main Site**: https://brisklearning.com (redirects to https://prod.brisklearning.com)
- **n8n Interface**: https://n8n.prod.brisklearning.com
- **API Webhooks**: https://api.prod.brisklearning.com/webhook/

## Database Integration

### PostgreSQL Connection Details:
- **Host**: scannedfiles.postgres.database.azure.com
- **User**: developergrowwstacks
- **Database**: processed
- **Port**: 5432
- **SSL Mode**: require

### Test Database Connection:
```bash
# From VM
docker exec -it file-processor psql -h scannedfiles.postgres.database.azure.com -U developergrowwstacks -d processed -c "SELECT version();"

# Check tables created by application
docker exec -it file-processor psql -h scannedfiles.postgres.database.azure.com -U developergrowwstacks -d processed -c "\dt"
```

### Vector Search Example:
```bash
# Search for similar documents
curl -X GET "https://api.dev.brisklearning.com/search?query=contract%20terms&limit=5"
```

## File Processing Workflow

### 1. File Upload via Web Interface:
- Visit https://dev.brisklearning.com
- Use file upload form
- Files are scanned with ClamAV
- Clean files get text extracted and vector embeddings
- Stored in PostgreSQL with pgvector

### 2. Form Data Processing:
- Submit data via web form
- Text is converted to embeddings
- Stored in same PostgreSQL database
- Searchable via vector similarity

### 3. API Integration:
```bash
# Upload file via API
curl -X POST -F "file=@document.pdf" -F "category=contract" https://api.dev.brisklearning.com/upload

# Submit form data via API  
curl -X POST -F "organization=TestOrg" -F "email=test@example.com" -F "description=Test data" https://api.dev.brisklearning.com/form/submit
```

## Troubleshooting

### Common Issues:

1. **SSL Certificates Not Working**:
   - Verify DNS records point to VM IP
   - Wait 5-10 minutes for Let's Encrypt
   - Check Caddy logs: `docker logs caddy`

2. **Database Connection Issues**:
   - Verify credentials in Key Vault
   - Test connection from VM: `psql -h scannedfiles.postgres.database.azure.com -U developergrowwstacks -d processed`
   - Check firewall rules on PostgreSQL server

3. **Services Not Starting**:
   - Check cloud-init logs: `sudo tail -f /var/log/cloud-init-output.log`
   - Verify Docker is running: `sudo systemctl status docker`
   - Check docker-compose: `docker-compose logs`

4. **File Processing Errors**:
   - Check ClamAV status: `docker logs clamav`
   - Verify file processor: `docker logs file-processor`
   - Check shared directories: `ls -la /home/azureuser/shared-files/`

### Monitoring Commands:
```bash
# Check all services
docker ps

# View logs
docker-compose logs -f

# Check SSL certificates
curl -vI https://dev.brisklearning.com

# Monitor file processing
tail -f /home/azureuser/logs/caddy/access.log
```

## Security Best Practices

1. **Change default passwords immediately after deployment**
2. **Restrict SSH access to specific IP addresses**
3. **Move database credentials to Key Vault**
4. **Enable Azure Monitor for logging and alerting**
5. **Regular security updates and patches**
6. **Backup strategy for database and files**

## Cost Estimation

### Development: ~$180/month
- VM: Standard_D2s_v3 (~$70/month)
- Storage: Standard LRS (~$20/month)
- Key Vault: (~$5/month)
- Network: (~$10/month)
- External PostgreSQL: (existing, no additional cost)

### Production: ~$350/month  
- VM: Standard_D8s_v3 (~$280/month)
- Storage: Premium ZRS (~$40/month)
- Key Vault: (~$10/month)
- Network: (~$20/month)

This deployment provides a complete, enterprise-grade data processing platform with automatic SSL, virus scanning, AI-powered search, and multi-environment support for BriskLearning.
