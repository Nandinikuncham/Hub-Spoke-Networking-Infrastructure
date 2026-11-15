output "resource_group_name" {
  value = data.azurerm_resource_group.deployment.name
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "jump_vm_public_ip" {
  description = "Public IP for SSH access to the jump VM"
  value       = azurerm_public_ip.jump.ip_address
}

output "jump_vm_private_ip" {
  value = azurerm_network_interface.jump.private_ip_address
}

output "spoke_vnet_names" {
  value = {
    for key, vnet in azurerm_virtual_network.spoke : key => vnet.name
  }
}
