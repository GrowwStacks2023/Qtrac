# VM and Network Outputs
output "vm_public_ip" {
  description = "Public IP address of the main VM"
  value       = azurerm_public_ip.main_vm_ip.ip_address
}

output "vm_name" {
  description = "Name of the main virtual machine"
  value       = azurerm_linux_virtual_machine.main_vm.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main_vnet.id
}

# PostgreSQL Outputs (Existing Server)
output "postgres_host" {
  description = "PostgreSQL server hostname"
  value       = var.postgres_host
  sensitive   = true
}

output "postgres_database" {
  description = "PostgreSQL database name"
  value       = var.postgres_database
  sensitive   = true
}

output "postgres_user" {
  description = "PostgreSQL username"
  value       = var.postgres_user
  sensitive   = true
}

# Storage Outputs
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main_storage.name
}

output "storage_account_primary_endpoint" {
  description = "Primary endpoint of the storage account"
  value       = azurerm_storage_account.main_storage.primary_blob_endpoint
}

# Key Vault Outputs
output "key_vault_name" {
  description = "Name of the key vault"
  value       = azurerm_key_vault.main_keyvault.name
}

output "key_vault_url" {
  description = "URL of the key vault"
  value       = azurerm_key_vault.main_keyvault.vault_uri
}

# BriskLearning Service URLs
output "main_website_url" {
  description = "Main website URL with environment subdomain"
  value       = "https://${var.environment}.${var.domain_name}"
}

output "n8n_url" {
  description = "n8n workflow manager URL with environment subdomain"
  value       = "https://n8n.${var.environment}.${var.domain_name}"
}

output "api_webhook_url" {
  description = "API webhook base URL with environment subdomain"
  value       = "https://api.${var.environment}.${var.domain_name}"
}

output "health_check_url" {
  description = "Health check endpoint URL"
  value       = "http://${azurerm_public_ip.main_vm_ip.ip_address}:8080/health"
}

# Connection Information
output "ssh_connection_command" {
  description = "SSH command to connect to the VM (using password auth)"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main_vm_ip.ip_address}"
}

output "postgres_connection_test" {
  description = "Command to test PostgreSQL connection from VM"
  value       = "psql -h ${var.postgres_host} -U ${var.postgres_user} -d ${var.postgres_database} -c 'SELECT version();'"
  sensitive   = true
}

# DNS Configuration Commands
output "dns_configuration_commands" {
  description = "DNS records that need to be configured for your domain"
  value = {
    "main_a_record" = "Create A record: ${var.environment}.${var.domain_name} -> ${azurerm_public_ip.main_vm_ip.ip_address}"
    "n8n_a_record" = "Create A record: n8n.${var.environment}.${var.domain_name} -> ${azurerm_public_ip.main_vm_ip.ip_address}"
    "api_a_record" = "Create A record: api.${var.environment}.${var.domain_name} -> ${azurerm_public_ip.main_vm_ip.ip_address}"
    "root_redirect" = "Create A record (prod only): ${var.domain_name} -> ${azurerm_public_ip.main_vm_ip.ip_address}"
  }
}

# Security Information
output "key_vault_secrets_stored" {
  description = "List of secrets stored in Key Vault"
  value = [
    "vm-admin-password",
    "postgres-host",
    "postgres-user",
    "postgres-password",
    "postgres-database",
    "postgres-connection-string"
  ]
}

# Setup Verification Commands
output "setup_verification_commands" {
  description = "Commands to verify BriskLearning setup"
  value = {
    "1_connect_to_vm" = "ssh ${var.admin_username}@${azurerm_public_ip.main_vm_ip.ip_address}"
    "2_check_services" = "docker ps"
    "3_view_logs" = "docker-compose logs -f"
    "4_test_postgres" = "docker exec file-processor psql $POSTGRES_CONNECTION -c 'SELECT version();'"
    "5_check_n8n" = "curl -I https://n8n.${var.environment}.${var.domain_name}"
    "6_test_webhook" = "curl -X POST https://api.${var.environment}.${var.domain_name}/webhook/test"
    "7_health_check" = "curl http://${azurerm_public_ip.main_vm_ip.ip_address}:8080/health"
    "8_check_cloud_init" = "tail -f /var/log/cloud-init-output.log"
    "9_check_setup_logs" = "tail -f /var/log/brisklearning-setup.log"
  }
}

# Environment-Specific Information
output "environment_info" {
  description = "Environment-specific configuration details"
  value = {
    "environment" = var.environment
    "deployment_version" = var.deployment_version
    "domain_pattern" = "${var.environment}.${var.domain_name}"
    "vm_size" = var.vm_size
    "storage_tier" = var.storage_account_tier
    "n8n_credentials" = "admin / BriskLearning2024!"
    "vm_admin_username" = var.admin_username
  }
}

# Resource Group Information
output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = data.azurerm_resource_group.main.location
}

# Resource Naming Information
output "resource_naming_info" {
  description = "Information about how resources are named in this deployment"
  value = {
    "vm_name" = azurerm_linux_virtual_machine.main_vm.name
    "storage_account" = azurerm_storage_account.main_storage.name
    "key_vault" = azurerm_key_vault.main_keyvault.name
    "virtual_network" = azurerm_virtual_network.main_vnet.name
    "public_ip" = azurerm_public_ip.main_vm_ip.name
    "network_security_group" = azurerm_network_security_group.vm_nsg.name
  }
}