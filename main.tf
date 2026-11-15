data "azurerm_resource_group" "deployment" {
  name = var.resource_group_name
}

locals {
  spokes = {
    development = {
      name    = "vnet-spoke-development"
      address = "10.1.0.0/16"
      subnet  = "snet-development"
      prefix  = "10.1.1.0/24"
    }
    testing = {
      name    = "vnet-spoke-testing"
      address = "10.2.0.0/16"
      subnet  = "snet-testing"
      prefix  = "10.2.1.0/24"
    }
    production_app = {
      name    = "vnet-spoke-prod-app"
      address = "10.3.0.0/16"
      subnet  = "snet-prod-app"
      prefix  = "10.3.1.0/24"
    }
    production_data = {
      name    = "vnet-spoke-prod-data"
      address = "10.4.0.0/16"
      subnet  = "snet-prod-data"
      prefix  = "10.4.1.0/24"
    }
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-centralindia"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.deployment.location
  resource_group_name = data.azurerm_resource_group.deployment.name
}

resource "azurerm_subnet" "hub_management" {
  name                 = "snet-management"
  resource_group_name  = data.azurerm_resource_group.deployment.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network" "spoke" {
  for_each = local.spokes

  name                = each.value.name
  address_space       = [each.value.address]
  location            = data.azurerm_resource_group.deployment.location
  resource_group_name = data.azurerm_resource_group.deployment.name
}

resource "azurerm_subnet" "spoke" {
  for_each = local.spokes

  name                 = each.value.subnet
  resource_group_name  = data.azurerm_resource_group.deployment.name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.prefix]
}

resource "azurerm_network_security_group" "hub" {
  name                = "nsg-hub-management"
  location            = data.azurerm_resource_group.deployment.location
  resource_group_name = data.azurerm_resource_group.deployment.name

  security_rule {
    name                       = "Allow-SSH-From-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_ip_cidr
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

resource "azurerm_subnet_network_security_group_association" "hub" {
  subnet_id                 = azurerm_subnet.hub_management.id
  network_security_group_id = azurerm_network_security_group.hub.id
}

resource "azurerm_network_security_group" "spoke" {
  for_each = local.spokes

  name                = "nsg-${each.key}"
  location            = data.azurerm_resource_group.deployment.location
  resource_group_name = data.azurerm_resource_group.deployment.name

  security_rule {
    name                       = "Allow-SSH-From-Hub-Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
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
  resource_group_name       = data.azurerm_resource_group.deployment.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = data.azurerm_resource_group.deployment.name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

resource "azurerm_public_ip" "jump" {
  name                = "pip-jump-vm"
  location            = data.azurerm_resource_group.deployment.location
  resource_group_name = data.azurerm_resource_group.deployment.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "jump" {
  name                = "nic-jump-vm"
  location            = data.azurerm_resource_group.deployment.location
  resource_group_name = data.azurerm_resource_group.deployment.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hub_management.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump.id
  }
}

resource "azurerm_linux_virtual_machine" "jump" {
  name                            = "vm-jump-centralindia"
  computer_name                   = "jumpvm"
  resource_group_name             = data.azurerm_resource_group.deployment.name
  location                        = data.azurerm_resource_group.deployment.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.jump.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-jump-vm"
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
