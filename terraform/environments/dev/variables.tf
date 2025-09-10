# Variables for existing infrastructure

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "existing_resource_group" {
  description = "Name of existing resource group"
  type        = string
  default     = "your-existing-rg-name"
}

variable "existing_vm_name" {
  description = "Name of existing VM with n8n and ClamAV"
  type        = string
  default     = "your-existing-vm-name"
}

variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "East US 2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
