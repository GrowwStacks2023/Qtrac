# BriskLearning Security Configuration

## Critical Security Actions Required

### 1. Move Database Credentials to Key Vault (IMMEDIATE)

**Current Issue**: Database password is stored in terraform.tfvars files in plain text.

**Solution**: Use Azure Key Vault references instead.

```bash
# Store password in Key Vault
az keyvault secret set \
  --vault-name "brisklearning-dev-kv" \
  --name "existing-postgres-password" \
  --value "palash2003@"

# Update main.tf to reference Key Vault
# Instead of: var.existing_postgres_password
# Use: data.azurerm_key_vault_secret.postgres_password.value
```

**Updated Terraform Configuration**:
```hcl
# In main.tf, add this data source:
data "azurerm_key_vault_secret" "existing_postgres_password" {
  name         = "existing-postgres-password"
  key_vault_id = azurerm_key_vault.main_keyvault.id
}

# Update the connection string to use:
postgres_password = data.azurerm_key_vault_secret.existing_postgres_password.value
```

### 2. Environment Variable Security

**Replace hardcoded credentials in cloud-init.yml**:
```yaml
# BEFORE (insecure):
PGPASSWORD=palash2003@

# AFTER (secure):
PGPASSWORD=$(az keyvault secret show --vault-name ${key_vault_name} --name existing-postgres-password --query value -o tsv)
```

### 3. Network Security Hardening

**Update NSG rules to restrict access**:
```bash
# Remove broad SSH access, replace with specific IP
az network nsg rule update \
  --resource-group "palash" \
  --nsg-name "brisklearning-dev-vm-nsg" \
  --name "SSH" \
  --source-address-prefix "YOUR_PUBLIC_IP/32"
```

### 4. SSL Certificate Security

**Ensure certificates are properly configured**:
- Domain must resolve before deployment
- Email must be valid and monitored
- Certificates will auto-renew via Caddy

### 5. Database Connection Security

**Enable SSL and configure proper authentication**:
```bash
# Test secure connection
psql "postgresql://developergrowwstacks:palash2003%40@scannedfiles.postgres.database.azure.com:5432/processed?sslmode=require"

# Verify SSL is working
psql -h scannedfiles.postgres.database.azure.com -U developergrowwstacks -d processed -c "SELECT ssl_is_used();"
```

## DNS Configuration Requirements

### Required DNS Records for brisklearning.com:

```dns
# A Records (replace IP_ADDRESS with your VM's public IP)
dev.brisklearning.com.     300    IN    A    IP_ADDRESS
test.brisklearning.com.    300    IN    A    IP_ADDRESS  
prod.brisklearning.com.    300    IN    A    IP_ADDRESS
n8n.dev.brisklearning.com. 300    IN    A    IP_ADDRESS
n8n.test.brisklearning.com. 300   IN    A    IP_ADDRESS
n8n.prod.brisklearning.com. 300   IN    A    IP_ADDRESS
api.dev.brisklearning.com.  300   IN    A    IP_ADDRESS
api.test.brisklearning.com. 300   IN    A    IP_ADDRESS
api.prod.brisklearning.com. 300   IN    A    IP_ADDRESS

# Root domain (production only)
brisklearning.com.         300    IN    A    IP_ADDRESS
```

### DNS Configuration Commands:
```bash
# After deployment, get the IP address
VM_IP=$(terraform output -raw vm_public_ip)

# Configure DNS records in your domain registrar
# Each subdomain should point to: $VM_IP
```

## Secure Deployment Checklist

### Pre-Deployment:
- [ ] Store database password in Key Vault
- [ ] Configure DNS records
- [ ] Update terraform.tfvars to remove plain text passwords
- [ ] Verify Azure service principal permissions

### Post-Deployment:
- [ ] Change default n8n password
- [ ] Restrict SSH access to specific IPs
- [ ] Verify SSL certificates are working
- [ ] Test database connectivity with SSL
- [ ] Enable Azure Monitor/Log Analytics
- [ ] Configure backup strategies

### Environment-Specific Security:

**Development (dev.brisklearning.com)**:
- Basic authentication sufficient
- Broader network access for testing
- Non-critical data only

**Test (test.brisklearning.com)**:
- Production-like security
- Limited access to test team
- Sanitized production data

**Production (brisklearning.com)**:
- Maximum security settings
- IP restrictions for admin access
- Full monitoring and alerting
- Regular security audits

## Monitoring and Alerting

### Required Monitoring:
```bash
# Set up alerts for:
# 1. Failed login attempts
# 2. Unusual database access patterns
# 3. SSL certificate expiration (30 days)
# 4. High resource usage
# 5. Failed file uploads/processing
```

### Log Monitoring:
```bash
# Monitor these logs:
tail -f /home/azureuser/logs/caddy/access.log
docker logs n8n
docker logs clamav
docker logs file-processor
```

## Backup and Recovery

### Database Backup:
```bash
# Create automated backup script
pg_dump "postgresql://developergrowwstacks:palash2003%40@scannedfiles.postgres.database.azure.com:5432/processed" > backup_$(date +%Y%m%d).sql
```

### File Storage Backup:
```bash
# Azure Storage has built-in redundancy
# Configure additional backups for critical files
```

This security configuration ensures your BriskLearning platform follows enterprise security best practices while maintaining functionality across all environments.
