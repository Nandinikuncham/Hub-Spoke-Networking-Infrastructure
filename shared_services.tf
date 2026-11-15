data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "shared" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.identity.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

resource "azurerm_recovery_services_vault" "shared" {
  name                = "rsv-hub-spoke-centralindia"
  location            = var.location
  resource_group_name = azurerm_resource_group.identity.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
  soft_delete_enabled = true
}

resource "azurerm_network_watcher" "shared" {
  count = var.create_network_watcher ? 1 : 0

  name                = "NetworkWatcher_${var.location}"
  location            = var.location
  resource_group_name = "NetworkWatcherRG"
}
