output "connectivity_resource_group_name" {
  value = azurerm_resource_group.connectivity.name
}

output "identity_resource_group_name" {
  value = azurerm_resource_group.identity.name
}

output "database_resource_group_name" {
  value = azurerm_resource_group.shared_data.name
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "bastion_name" {
  value = azurerm_bastion_host.hub.name
}

output "firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "vpn_gateway_name" {
  value = azurerm_virtual_network_gateway.hub.name
}

output "spoke_vm_private_ips" {
  description = "Private IPs of the three spoke VMs"
  value = {
    for key, nic in azurerm_network_interface.spoke : key => nic.private_ip_address
  }
}

output "spoke_lb_private_ips" {
  description = "Private frontend IPs of the three spoke SSH load balancers"
  value = {
    for key, lb in azurerm_lb.spoke_ssh : key => lb.frontend_ip_configuration[0].private_ip_address
  }
}

output "spoke_vnet_names" {
  value = {
    for key, vnet in azurerm_virtual_network.spoke : key => vnet.name
  }
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  value = azapi_resource.sql_database.name
}

output "monitoring_workspace_name" {
  description = "Log Analytics workspace receiving spoke VM performance metrics"
  value       = azurerm_log_analytics_workspace.vm_monitoring.name
}

output "monitoring_workbook_id" {
  description = "Azure resource ID of the Hub-Spoke VM Health workbook"
  value       = azurerm_application_insights_workbook.vm_health.id
}
