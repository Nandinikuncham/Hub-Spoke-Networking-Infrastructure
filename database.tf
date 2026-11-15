resource "azurerm_mssql_server" "sql" {
  name                          = var.sql_server_name
  resource_group_name           = azurerm_resource_group.shared_data.name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
}

resource "azapi_resource" "sql_database" {
  type      = "Microsoft.Sql/servers/databases@2023-08-01-preview"
  name      = var.sql_database_name
  parent_id = azurerm_mssql_server.sql.id
  location  = var.location

  body = {
    sku = {
      name     = "GP_S_Gen5"
      tier     = "GeneralPurpose"
      family   = "Gen5"
      capacity = 2
    }

    properties = {
      autoPauseDelay                   = 60
      minCapacity                      = 0.5
      maxSizeBytes                     = 34359738368
      requestedBackupStorageRedundancy = "Local"
      useFreeLimit                     = true
      freeLimitExhaustionBehavior      = "AutoPause"
    }
  }
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.shared_data.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  for_each = merge(
    { hub = azurerm_virtual_network.hub.id },
    { for key, vnet in azurerm_virtual_network.spoke : key => vnet.id }
  )

  name                  = "sql-${each.key}-link"
  resource_group_name   = azurerm_resource_group.shared_data.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = each.value
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-shared-data"
  location            = var.location
  resource_group_name = azurerm_resource_group.connectivity.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-sql-shared-data"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
