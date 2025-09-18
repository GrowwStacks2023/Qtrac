# Development Environment Configuration
environment = "dev"
project_name = "brisklearning"
location = "centralindia"
resource_group_name = "arslan"

# VM Configuration
vm_size = "Standard_D2s_v3"  # Smaller size for dev
admin_username = "azureuser"

# Domain Configuration
domain_name = "brisklearning.com"
ssl_email = "admin@brisklearning.com"

# Existing PostgreSQL Configuration (SECURE - Use Key Vault in production)
existing_postgres_host = "scannedfiles.postgres.database.azure.com"
existing_postgres_user = "developergrowwstacks"
existing_postgres_password = palash2003@"
existing_postgres_database = "processed"
existing_postgres_port = "5432"

# Storage Configuration
storage_account_tier = "Standard"
storage_replication_type = "LRS"

# Network Configuration
vnet_address_space = ["10.0.0.0/16"]
subnet_address_prefix = ["10.0.1.0/24"]

# Tags
common_tags = {
  Environment = "dev"
  Project     = "BriskLearning"
  ManagedBy   = "terraform"
  Purpose     = "data-processing"
  Owner       = "developergrowwstacks"
}
