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
  tenant_id      = "f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
}

# Get current client config
data "azurerm_client_config" "current" {}

# Resource Group (assuming it already exists)
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Network Security Group for Dev
resource "azurerm_network_security_group" "dev_main_nsg" {
  name                = "githubtest1-nsg"
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

# VM Network Security Group for Dev
resource "azurerm_network_security_group" "dev_vm_nsg" {
  name                = "githubtest1-vm-nsg"
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

# Public IP for Dev VM
resource "azurerm_public_ip" "dev_vm_ip" {
  name                = "githubtest1-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "dev_vnet" {
  name                = "githubtest1-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Subnet for Dev
resource "azurerm_subnet" "dev_subnet" {
  name                 = "githubtest1-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.dev_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Network Interface for Dev VM
resource "azurerm_network_interface" "dev_vm_nic" {
  name                = "githubtest1-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dev_vm_ip.id
  }

  tags = {
    Environment = var.environment
    Project     = "githubtest"
  }
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "dev_vm_nsg_association" {
  network_interface_id      = azurerm_network_interface.dev_vm_nic.id
  network_security_group_id = azurerm_network_security_group.dev_vm_nsg.id
}

# Key Vault for Dev
resource "azurerm_key_vault" "dev_keyvault" {
  name                = "githubtest1-kv"
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

# Storage Account for Dev
resource "azurerm_storage_account" "dev_storage" {
  name                     = "githubtest1storage"
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

# Generate SSH key pair (TLS)
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key in Key Vault
resource "azurerm_key_vault_secret" "vm_ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = tls_private_key.vm_ssh.private_key_pem
  key_vault_id = azurerm_key_vault.dev_keyvault.id

  depends_on = [azurerm_key_vault.dev_keyvault]

  tags = {
    Environment = var.environment
    Purpose     = "vm-access"
  }
}

# Store public key in Key Vault
resource "azurerm_key_vault_secret" "vm_ssh_public_key" {
  name         = "vm-ssh-public-key"
  value        = tls_private_key.vm_ssh.public_key_openssh
  key_vault_id = azurerm_key_vault.dev_keyvault.id

  depends_on = [azurerm_key_vault.dev_keyvault]

  tags = {
    Environment = var.environment
    Purpose     = "vm-access"
  }
}

# Virtual Machine for Dev (uses generated public key)
resource "azurerm_linux_virtual_machine" "dev_vm" {
  name                = "${var.project_name}-${var.environment}-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.dev_vm_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
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

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "n8n-dev"
    Name        = "${var.project_name}-${var.environment}-vm"
  })
}
