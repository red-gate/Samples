output "vm_ip" {
  description = "Public IP of the VM"
  value       = azurerm_public_ip.public_ip.ip_address
}

output "vm_username" {
  description = "VM username"
  value       = var.vm_username
}

output "vm_password" {
  description = "Password of the VM user"
  value       = var.vm_password
}

output "vm_name" {
  description = "Name of the VM"
  value = var.vm_name
}

output "vm_resource_group_name" {
  description = "Name of the resource group where the VM lives"
  value = var.resource_group_name
}