data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "shared" {
  name                          = var.key_vault_name
  location                      = var.location
  resource_group_name           = azurerm_resource_group.identity.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  public_network_access_enabled = false
}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.identity.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  for_each = merge(
    { hub = azurerm_virtual_network.hub.id },
    { for key, vnet in azurerm_virtual_network.spoke : key => vnet.id }
  )

  name                  = "key-vault-${each.key}-link"
  resource_group_name   = azurerm_resource_group.identity.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = each.value
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-key-vault-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.connectivity.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-key-vault"
    private_connection_resource_id = azurerm_key_vault.shared.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "key-vault-private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }
}

resource "azurerm_recovery_services_vault" "shared" {
  name                = "rsv-hub-spoke-centralindia"
  location            = var.location
  resource_group_name = azurerm_resource_group.identity.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
}

resource "azurerm_backup_policy_vm" "spoke_daily" {
  name                = "backup-spoke-vms-daily-30-days"
  resource_group_name = azurerm_resource_group.identity.name
  recovery_vault_name = azurerm_recovery_services_vault.shared.name
  timezone            = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }
}

resource "azurerm_backup_protected_vm" "spoke" {
  for_each = azurerm_linux_virtual_machine.spoke

  resource_group_name = azurerm_resource_group.identity.name
  recovery_vault_name = azurerm_recovery_services_vault.shared.name
  source_vm_id        = each.value.id
  backup_policy_id    = azurerm_backup_policy_vm.spoke_daily.id
}

resource "azurerm_network_watcher" "shared" {
  count = var.create_network_watcher ? 1 : 0

  name                = "NetworkWatcher_${var.location}"
  location            = var.location
  resource_group_name = "NetworkWatcherRG"
}
