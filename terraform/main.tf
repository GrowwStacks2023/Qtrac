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

# Virtual Network
resource "azurerm_virtual_network" "main_vnet" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-vnet"
  })
}

# Subnet for VMs
resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.project_name}-${var.environment}-vm-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group for VMs
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.project_name}-${var.environment}-vm-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  # SSH access
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

  # n8n web interface
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

  # HTTP for web apps
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

  # HTTPS for web apps
  security_rule {
    name                       = "HTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ClamAV daemon port (internal use)
  security_rule {
    name                       = "ClamAV"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3310"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-vm-nsg"
  })
}

# Associate NSG with VM subnet
resource "azurerm_subnet_network_security_group_association" "vm_nsg_association" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Public IP for the main VM
resource "azurerm_public_ip" "main_vm_ip" {
  name                = "${var.project_name}-${var.environment}-vm-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-vm-ip"
  })
}

# Network Interface for main VM
resource "azurerm_network_interface" "main_vm_nic" {
  name                = "${var.project_name}-${var.environment}-vm-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main_vm_ip.id
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-vm-nic"
  })
}

# Key Vault for storing secrets
resource "azurerm_key_vault" "main_keyvault" {
  name                = "${var.project_name}-${var.environment}-kv"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = "f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
  sku_name            = var.key_vault_sku

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = var.purge_protection_enabled

  access_policy {
    tenant_id = "f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-kv"
  })
}

# Storage Account for file processing
resource "azurerm_storage_account" "main_storage" {
  name                     = "${lower(var.project_name)}${var.environment}storage"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-storage"
  })
}

# Storage containers for different file types
resource "azurerm_storage_container" "incoming_files" {
  name                  = "incoming-files"
  storage_account_name  = azurerm_storage_account.main_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "scanned_clean" {
  name                  = "scanned-clean"
  storage_account_name  = azurerm_storage_account.main_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "quarantine" {
  name                  = "quarantine"
  storage_account_name  = azurerm_storage_account.main_storage.name
  container_access_type = "private"
}

# Generate SSH key pair
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH keys in Key Vault
resource "azurerm_key_vault_secret" "vm_ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = tls_private_key.vm_ssh.private_key_pem
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "vm-access"
  })
}

resource "azurerm_key_vault_secret" "vm_ssh_public_key" {
  name         = "vm-ssh-public-key"
  value        = tls_private_key.vm_ssh.public_key_openssh
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "vm-access"
  })
}

# Store PostgreSQL credentials in Key Vault (EXISTING SERVER)
resource "azurerm_key_vault_secret" "postgres_host" {
  name         = "postgres-host"
  value        = var.existing_postgres_host
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database-config"
  })
}

resource "azurerm_key_vault_secret" "postgres_user" {
  name         = "postgres-user"
  value        = var.existing_postgres_user
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database-config"
  })
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = var.existing_postgres_password
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database-config"
  })
}

resource "azurerm_key_vault_secret" "postgres_database" {
  name         = "postgres-database"
  value        = var.existing_postgres_database
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database-config"
  })
}

resource "azurerm_key_vault_secret" "postgres_connection_string" {
  name         = "postgres-connection-string"
  value        = "postgresql://${var.existing_postgres_user}:${var.existing_postgres_password}@${var.existing_postgres_host}:${var.existing_postgres_port}/${var.existing_postgres_database}?sslmode=require"
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database-access"
  })
}

# Main VM for n8n and ClamAV
resource "azurerm_linux_virtual_machine" "main_vm" {
  name                = "${var.project_name}-${var.environment}-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.main_vm_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.vm_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Custom data script to install Docker, n8n, ClamAV, and Caddy
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yml", {
    postgres_connection_string = "postgresql://${var.existing_postgres_user}:${var.existing_postgres_password}@${var.existing_postgres_host}:${var.existing_postgres_port}/${var.existing_postgres_database}?sslmode=require"
    postgres_host = var.existing_postgres_host
    postgres_user = var.existing_postgres_user
    postgres_password = var.existing_postgres_password
    postgres_database = var.existing_postgres_database
    postgres_port = var.existing_postgres_port
    storage_account_name = azurerm_storage_account.main_storage.name
    storage_account_key = azurerm_storage_account.main_storage.primary_access_key
    domain_name = var.domain_name
    ssl_email = var.ssl_email
    environment = var.environment
  }))

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "data-processing"
    Name        = "${var.project_name}-${var.environment}-vm"
  })

  depends_on = [
    azurerm_storage_account.main_storage
  ]
}2d1-e5f8d7326bfd"
  sku_name            = var.key_vault_sku

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = var.purge_protection_enabled

  access_policy {
    tenant_id = "f1845ecc-10c8-4389-a2d1-e5f8d7326bfd"
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-kv"
  })
}

# Storage Account for file processing
resource "azurerm_storage_account" "main_storage" {
  name                     = "${lower(var.project_name)}${var.environment}storage"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-storage"
  })
}

# Storage containers for different file types
resource "azurerm_storage_container" "incoming_files" {
  name                  = "incoming-files"
  storage_account_name  = azurerm_storage_account.main_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "scanned_clean" {
  name                  = "scanned-clean"
  storage_account_name  = azurerm_storage_account.main_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "quarantine" {
  name                  = "quarantine"
  storage_account_name  = azurerm_storage_account.main_storage.name
  container_access_type = "private"
}

# PostgreSQL Flexible Server with pgvector support
resource "azurerm_postgresql_flexible_server" "main_postgres" {
  name                   = "${var.project_name}-${var.environment}-postgres"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = var.location
  version                = "14"
  delegated_subnet_id    = azurerm_subnet.postgres_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres_dns.id
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  zone                   = "1"
  storage_mb             = var.postgres_storage_mb
  sku_name              = var.postgres_sku_name

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres_dns_link]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-postgres"
  })
}

# PostgreSQL Configuration for pgvector
resource "azurerm_postgresql_flexible_server_configuration" "pgvector_extension" {
  name      = "shared_preload_libraries"
  server_id = azurerm_postgresql_flexible_server.main_postgres.id
  value     = "vector"
}

# PostgreSQL Database for the application
resource "azurerm_postgresql_flexible_server_database" "app_database" {
  name      = var.app_database_name
  server_id = azurerm_postgresql_flexible_server.main_postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"

  depends_on = [azurerm_postgresql_flexible_server.main_postgres]
}

# Generate SSH key pair
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH keys in Key Vault
resource "azurerm_key_vault_secret" "vm_ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = tls_private_key.vm_ssh.private_key_pem
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "vm-access"
  })
}

resource "azurerm_key_vault_secret" "vm_ssh_public_key" {
  name         = "vm-ssh-public-key"
  value        = tls_private_key.vm_ssh.public_key_openssh
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "vm-access"
  })
}

# Store PostgreSQL credentials in Key Vault
resource "azurerm_key_vault_secret" "postgres_connection_string" {
  name         = "postgres-connection-string"
  value        = "postgresql://${var.postgres_admin_username}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.main_postgres.fqdn}:5432/${var.app_database_name}?sslmode=require"
  key_vault_id = azurerm_key_vault.main_keyvault.id

  depends_on = [azurerm_key_vault.main_keyvault]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database-access"
  })
}

# Main VM for n8n and ClamAV
resource "azurerm_linux_virtual_machine" "main_vm" {
  name                = "${var.project_name}-${var.environment}-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.main_vm_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.vm_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Custom data script to install Docker, n8n, ClamAV, and Caddy
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yml", {
    postgres_connection_string = "postgresql://${var.postgres_admin_username}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.main_postgres.fqdn}:5432/${var.app_database_name}?sslmode=require"
    storage_account_name = azurerm_storage_account.main_storage.name
    storage_account_key = azurerm_storage_account.main_storage.primary_access_key
    domain_name = var.domain_name
    ssl_email = var.ssl_email
  }))

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "data-processing"
    Name        = "${var.project_name}-${var.environment}-vm"
  })

  depends_on = [
    azurerm_postgresql_flexible_server.main_postgres,
    azurerm_storage_account.main_storage
  ]
}
