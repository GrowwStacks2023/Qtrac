terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "0c8d18ae-4640-4da5-9ca9-6684d674951a"
  tenant_id       = "f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "palash"
}

# Get current client config
data "azurerm_client_config" "current" {}

# Resource Group (assuming it already exists)
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Network Security Group for Test
resource "azurerm_network_security_group" "test_main_nsg" {
  name                = "githubtest2-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "n8n"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5678"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# VM Network Security Group for Test
resource "azurerm_network_security_group" "test_vm_nsg" {
  name                = "githubtest2-vm-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Public IP for Test VM
resource "azurerm_public_ip" "test_vm_ip" {
  name                = "githubtest2-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Virtual Network for Test
resource "azurerm_virtual_network" "test_vnet" {
  name                = "githubtest2-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Subnet for Test
resource "azurerm_subnet" "test_subnet" {
  name                 = "githubtest2-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.test_vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}

# Network Interface for Test VM
resource "azurerm_network_interface" "test_vm_nic" {
  name                = "githubtest2-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test_vm_ip.id
  }

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "test_vm_nsg_association" {
  network_interface_id      = azurerm_network_interface.test_vm_nic.id
  network_security_group_id = azurerm_network_security_group.test_vm_nsg.id
}

# Key Vault for Test
resource "azurerm_key_vault" "test_keyvault" {
  name                = "githubtest2-kv"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = "f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
  sku_name            = "standard"

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = false

  access_policy {
    tenant_id = "f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
  }

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Storage Account for Test
resource "azurerm_storage_account" "test_storage" {
  name                     = "githubtest2storage"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = "eastus2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # Data Lake Gen2

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# -----------------------------
# Generate SSH key pair (TLS)
# -----------------------------
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key in Key Vault
resource "azurerm_key_vault_secret" "vm_ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = tls_private_key.vm_ssh.private_key_pem
  key_vault_id = azurerm_key_vault.test_keyvault.id

  depends_on = [azurerm_key_vault.test_keyvault]

  tags = {
    Environment = var.environment
    Purpose     = "vm-access"
  }
}

# Store public key in Key Vault
resource "azurerm_key_vault_secret" "vm_ssh_public_key" {
  name         = "vm-ssh-public-key"
  value        = tls_private_key.vm_ssh.public_key_openssh
  key_vault_id = azurerm_key_vault.test_keyvault.id

  depends_on = [azurerm_key_vault.test_keyvault]

  tags = {
    Environment = var.environment
    Purpose     = "vm-access"
  }
}

# Virtual Machine for Test (uses generated public key)
resource "azurerm_linux_virtual_machine" "test_vm" {
  name                = "githubtest2-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = "Standard_D2als_v5"  # Slightly larger for test
  admin_username      = "azureuser"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.test_vm_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.vm_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Environment = var.environment
    Project     = "githubtest"
    Purpose     = "n8n-test"
  }
}

# Outputs
output "test_vm_public_ip" {
  value = azurerm_public_ip.test_vm_ip.ip_address
}

output "test_vm_name" {
  value = azurerm_linux_virtual_machine.test_vm.name
}

output "test_storage_account" {
  value = azurerm_storage_account.test_storage.name
}

output "test_key_vault" {
  value = azurerm_key_vault.test_keyvault.name
}

# Helpful SSH outputs: command to connect and command to retrieve SSH private key
output "ssh_connection_command" {
  value       = "ssh -i ~/.ssh/vm_key azureuser@${azurerm_public_ip.test_vm_ip.ip_address}"
  description = "SSH command to connect to the VM (after retrieving private key)"
}

output "ssh_key_retrieval_command" {
  value       = "az keyvault secret show --vault-name ${azurerm_key_vault.test_keyvault.name} --name vm-ssh-private-key --query value -o tsv > ~/.ssh/vm_key && chmod 600 ~/.ssh/vm_key"
  description = "Command to retrieve SSH private key from Key Vault and set proper permissions"
}

