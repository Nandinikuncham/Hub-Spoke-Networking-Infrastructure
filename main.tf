locals {
  spokes = {
    development = {
      name                = "vnet-spoke-development"
      address             = "10.1.0.0/16"
      subnet              = "snet-development"
      prefix              = "10.1.1.0/24"
      resource_group_name = "rg-hub-spoke-development"
    }
    testing = {
      name                = "vnet-spoke-testing"
      address             = "10.2.0.0/16"
      subnet              = "snet-testing"
      prefix              = "10.2.1.0/24"
      resource_group_name = "rg-hub-spoke-testing"
    }
    production_app = {
      name                = "vnet-spoke-prod-app"
      address             = "10.3.0.0/16"
      subnet              = "snet-prod-app"
      prefix              = "10.3.1.0/24"
      resource_group_name = "rg-hub-spoke-production-app"
    }
  }
}

resource "azurerm_resource_group" "connectivity" {
  name     = var.connectivity_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "identity" {
  name     = var.identity_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "shared_data" {
  name     = var.shared_data_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "spoke" {
  for_each = local.spokes

  name     = each.value.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-centralindia"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.connectivity.name
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/27"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.4.0/24"]
}

resource "azurerm_virtual_network" "spoke" {
  for_each = local.spokes

  name                = each.value.name
  address_space       = [each.value.address]
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name
}

resource "azurerm_subnet" "spoke" {
  for_each = local.spokes

  name                 = each.value.subnet
  resource_group_name  = azurerm_resource_group.spoke[each.key].name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.prefix]
}

resource "azurerm_network_security_group" "spoke" {
  for_each = local.spokes

  name                = "nsg-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name

  security_rule {
    name                       = "Allow-SSH-From-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.2.0/26"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Azure-LB-Probe-SSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Other-VNet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.spokes

  subnet_id                 = azurerm_subnet.spoke[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.connectivity.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.spoke[each.key].name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

resource "azurerm_network_interface" "spoke" {
  for_each = local.spokes

  name                = "nic-${replace(each.key, "_", "-")}-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke[each.key].id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet_network_security_group_association.spoke]
}

resource "azurerm_linux_virtual_machine" "spoke" {
  for_each = local.spokes

  name                            = "vm-${replace(each.key, "_", "-")}-centralindia"
  computer_name                   = "${replace(each.key, "_", "-")}-vm"
  resource_group_name             = azurerm_resource_group.spoke[each.key].name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  identity {
    type = "SystemAssigned"
  }
  network_interface_ids = [azurerm_network_interface.spoke[each.key].id]

  os_disk {
    name                 = "osdisk-${replace(each.key, "_", "-")}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
