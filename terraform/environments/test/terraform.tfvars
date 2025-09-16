# Test Environment Configuration
environment = "test"
project_name = "brisklearning"
location = "southeastasia"  # Changed from centralindia to avoid quota issues
resource_group_name = "palash"

# VM Configuration
vm_size = "Standard_D4s_v3"  # Medium size for test
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
storage_account_tier = "Standard"
storage_replication_type = "GRS"  # Geo-redundant for test
deployment_version = "v1"

# Network Configuration
vnet_address_space = ["10.1.0.0/16"]  # Different IP range for test
subnet_address_prefix = ["10.1.1.0/24"]

# Tags
common_tags = {
  Environment = "test"
  Project     = "BriskLearning"
  ManagedBy   = "terraform"
  Purpose     = "data-processing"
  Owner       = "developergrowwstacks"
}
