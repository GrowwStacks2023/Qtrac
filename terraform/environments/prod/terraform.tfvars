# Production Environment Configuration
environment = "prod"
project_name = "brisklearning"
location = "centralindia"
resource_group_name = "palash"

# VM Configuration
vm_size = "Standard_D8s_v3"  # Large size for production
admin_username = "azureuser"

# Domain Configuration
domain_name = "brisklearning.com"
ssl_email = "admin@brisklearning.com"

# Existing PostgreSQL Configuration (SECURE - Use Key Vault in production)
existing_postgres_host = "scannedfiles.postgres.database.azure.com"
existing_postgres_user = "developergrowwstacks"
existing_postgres_password = "palash2003@"
existing_postgres_database = "processed"
existing_postgres_port = "5432"

# Storage Configuration
storage_account_tier = "Premium"
storage_replication_type = "ZRS"  # Zone-redundant for production

# Network Configuration
vnet_address_space = ["10.2.0.0/16"]  # Different IP range for production
subnet_address_prefix = ["10.2.1.0/24"]

# Key Vault Configuration
purge_protection_enabled = true  # Enable for production

# Tags
common_tags = {
  Environment = "prod"
  Project     = "BriskLearning"
  ManagedBy   = "terraform"
  Purpose     = "data-processing"
  Owner       = "developergrowwstacks"
  CriticalSystem = "true"
}
