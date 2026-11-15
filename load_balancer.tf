resource "azurerm_lb" "spoke_ssh" {
  for_each = local.spokes

  name                = "lb-${replace(each.key, "_", "-")}-ssh"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.deployment.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.spoke[each.key].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(each.value.prefix, 10)
  }
}

resource "azurerm_lb_backend_address_pool" "spoke_ssh" {
  for_each = local.spokes

  name            = "backend-${replace(each.key, "_", "-")}"
  loadbalancer_id = azurerm_lb.spoke_ssh[each.key].id
}

resource "azurerm_lb_probe" "spoke_ssh" {
  for_each = local.spokes

  name            = "ssh-tcp-22"
  loadbalancer_id = azurerm_lb.spoke_ssh[each.key].id
  protocol        = "Tcp"
  port            = 22
}

resource "azurerm_lb_rule" "spoke_ssh" {
  for_each = local.spokes

  name                           = "ssh-tcp-22"
  loadbalancer_id                = azurerm_lb.spoke_ssh[each.key].id
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "private"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.spoke_ssh[each.key].id]
  probe_id                       = azurerm_lb_probe.spoke_ssh[each.key].id
}

resource "azurerm_network_interface_backend_address_pool_association" "spoke_ssh" {
  for_each = local.spokes

  network_interface_id    = azurerm_network_interface.spoke[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.spoke_ssh[each.key].id
}
