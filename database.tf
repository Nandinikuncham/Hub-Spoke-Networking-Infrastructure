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
  for_each = local.spokes

  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.spoke[each.key].name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  for_each = local.spokes

  name                  = "sql-${each.key}-link"
  resource_group_name   = azurerm_resource_group.spoke[each.key].name
  private_dns_zone_name = azurerm_private_dns_zone.sql[each.key].name
  virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "sql" {
  for_each = local.spokes

  name                = "pe-sql-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared_data.name
  subnet_id           = azurerm_subnet.spoke_private_endpoints[each.key].id

  private_service_connection {
    name                           = "psc-sql-${each.key}"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql[each.key].id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.spoke_private_endpoints]
}
