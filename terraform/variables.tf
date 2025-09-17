# Environment Variables 
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "arslan"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "brisklearning"
}

# VM Configuration Variables
variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "admin_username" {
  description = "Admin username for the virtual machine"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  description = "Admin password for the virtual machine"
  type        = string
  sensitive   = true
}

# Storage Configuration
variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "GRS"
}

# Key Vault Configuration
variable "key_vault_sku" {
  description = "Key Vault SKU"
  type        = string
  default     = "standard"
}

variable "purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false
}

# Network Configuration
variable "vnet_address_space" {
  description = "Address space for virtual network"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Address prefix for subnet"
  type        = list(string)
  default     = ["10.1.1.0/24"]
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project      = "BriskLearning"
    ManagedBy    = "terraform"
    Purpose      = "data-processing"
    Owner        = "developergrowwstacks"
  }
}

# Deployment Version for Resource Naming
variable "deployment_version" {
  description = "Version suffix to avoid resource conflicts (e.g., v1, v2, v3)"
  type        = string
  default     = "v1"
  
  validation {
    condition     = can(regex("^v[0-9]+$", var.deployment_version))
    error_message = "Deployment version must follow format 'v1', 'v2', etc."
  }
}

# PostgreSQL Configuration Variables (MISSING FROM YOUR CURRENT FILE)
variable "postgres_host" {
  description = "PostgreSQL server hostname"
  type        = string
  sensitive   = true
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  sensitive   = true
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

# Application Configuration Variables (MISSING FROM YOUR CURRENT FILE)
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "ssl_email" {
  description = "Email address for SSL certificate generation"
  type        = string
}