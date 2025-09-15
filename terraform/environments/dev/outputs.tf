output "dev_vm_public_ip" {
  description = "Public IP address of the virtual machine"
  value       = azurerm_public_ip.dev_vm_ip.ip_address
}

output "dev_vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.dev_vm.name
}

output "dev_storage_account" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.dev_storage.name
}

output "dev_key_vault" {
  description = "Name of the key vault"
  value       = azurerm_key_vault.dev_keyvault.name
}

output "dev_key_vault_url" {
  description = "URL of the key vault"
  value       = azurerm_key_vault.dev_keyvault.vault_uri
}

output "dev_virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.dev_vnet.id
}

output "dev_subnet_id" {
  description = "ID of the subnet"
  value       = azurerm_subnet.dev_subnet.id
}

# SSH connection helper outputs
output "ssh_connection_command" {
  description = "SSH command to connect to the VM (after retrieving private key)"
  value       = "ssh -i ~/.ssh/vm_key ${var.admin_username}@${azurerm_public_ip.dev_vm_ip.ip_address}"
}

output "ssh_key_retrieval_command" {
  description = "Command to retrieve SSH private key from Key Vault and set proper permissions"
  value       = "az keyvault secret show --vault-name ${azurerm_key_vault.dev_keyvault.name} --name vm-ssh-private-key --query value -o tsv > ~/.ssh/vm_key && chmod 600 ~/.ssh/vm_key"
}

# Resource group information
output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = data.azurerm_resource_group.main.location
}
