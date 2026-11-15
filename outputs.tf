output "resource_group_name" {
  value = data.azurerm_resource_group.deployment.name
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "jump_vm_public_ip" {
  description = "Public IP for password-based SSH access to the hub jump VM"
  value       = azurerm_public_ip.jump.ip_address
}

output "jump_vm_private_ip" {
  description = "Private IP of the hub jump VM"
  value       = azurerm_network_interface.jump.private_ip_address
}

output "spoke_vm_private_ips" {
  description = "Private IPs of the spoke VMs"
  value = {
    for key, nic in azurerm_network_interface.spoke : key => nic.private_ip_address
  }
}

output "spoke_lb_private_ips" {
  description = "Private frontend IPs of the spoke SSH load balancers; connect from the hub jump VM"
  value = {
    for key, lb in azurerm_lb.spoke_ssh : key => lb.frontend_ip_configuration[0].private_ip_address
  }
}

output "spoke_vnet_names" {
  value = {
    for key, vnet in azurerm_virtual_network.spoke : key => vnet.name
  }
}

output "monitoring_workspace_name" {
  description = "Log Analytics workspace receiving VM performance metrics"
  value       = azurerm_log_analytics_workspace.vm_monitoring.name
}

output "monitoring_workbook_id" {
  description = "Azure resource ID of the Hub-Spoke VM Health workbook"
  value       = azurerm_application_insights_workbook.vm_health.id
}
