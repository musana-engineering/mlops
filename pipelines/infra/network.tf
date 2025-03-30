resource "azurerm_resource_group" "ml" {
  name     = "gbj-ml-prod-rg"
  location = local.location
  tags     = local.tags
}

resource "azurerm_network_watcher" "watcher" {
  name                = "gbj-ml-prod-nw"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name

  tags = local.tags

  depends_on = [azurerm_resource_group.ml]
}

resource "azurerm_network_security_group" "bas" {
  name                = "gbj-ml-prod-bas"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name

  security_rule {
    name                       = "AllowHttpsInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "Internet"
    destination_port_range     = "443"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManagerInBound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "GatewayManager"
    destination_port_range     = "443"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLoadBalancerInBound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_port_range     = "443"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowbasHostCommunicationInBound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["8080", "5701"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInBound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSshRdpOutBound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_ranges    = ["22", "3389"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureCloudCommunicationOutBound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "443"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "AllowbasHostCommunicationOutBound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["8080", "5701"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowGetSessionInformationOutBound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_ranges    = ["80", "443"]
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "DenyAllOutBound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "ml" {
  name                = "gbj-ml-prod-ml"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name

}

resource "azurerm_virtual_network" "ml" {
  name                = "gbj-ml-prod-vnet"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name
  address_space       = local.vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "bas" {
  name                                          = "AzureBastionSubnet"
  resource_group_name                           = azurerm_resource_group.ml.name
  virtual_network_name                          = azurerm_virtual_network.ml.name
  address_prefixes                              = local.bastion_subnet_cidr
  private_link_service_network_policies_enabled = true
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.ContainerRegistry",
    "Microsoft.AzureCosmosDB",
    "Microsoft.KeyVault",
    "Microsoft.ServiceBus",
    "Microsoft.EventHub",
    "Microsoft.AzureActiveDirectory",
  "Microsoft.Web"]

  depends_on = [azurerm_network_security_group.bas,
  azurerm_network_security_group.ml]
}

resource "azurerm_subnet" "ml" {
  name                                          = "gbj-ml-prod-ml"
  resource_group_name                           = azurerm_resource_group.ml.name
  virtual_network_name                          = azurerm_virtual_network.ml.name
  address_prefixes                              = local.ml_subnet_cidr
  private_link_service_network_policies_enabled = true
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.ContainerRegistry",
    "Microsoft.AzureCosmosDB",
    "Microsoft.KeyVault",
    "Microsoft.ServiceBus",
    "Microsoft.EventHub",
    "Microsoft.AzureActiveDirectory",
  "Microsoft.Web"]

  depends_on = [azurerm_network_security_group.bas,
  azurerm_network_security_group.ml]
}

resource "azurerm_subnet_network_security_group_association" "ml" {
  subnet_id                 = azurerm_subnet.ml.id
  network_security_group_id = azurerm_network_security_group.ml.id

  depends_on = [azurerm_network_security_group.bas,
  azurerm_network_security_group.ml]
}

resource "azurerm_subnet_network_security_group_association" "bas" {
  subnet_id                 = azurerm_subnet.bas.id
  network_security_group_id = azurerm_network_security_group.bas.id

  depends_on = [azurerm_network_security_group.bas,
  azurerm_network_security_group.ml]
}

resource "azurerm_private_dns_zone" "dns" {
  for_each            = toset(local.private_dns_zones)
  name                = each.value
  resource_group_name = azurerm_resource_group.ml.name
}

data "azurerm_virtual_network" "ml" {
  name                = azurerm_virtual_network.ml.name
  resource_group_name = azurerm_resource_group.ml.name
  depends_on          = [azurerm_virtual_network.ml]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns" {
  for_each              = toset(local.private_dns_zones)
  name                  = azurerm_virtual_network.ml.name
  resource_group_name   = azurerm_resource_group.ml.name
  private_dns_zone_name = each.value
  virtual_network_id    = data.azurerm_virtual_network.ml.id
  tags                  = local.tags
}

resource "azurerm_public_ip" "bas" {
  name                = "gbj-ml-prod-bas"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_virtual_network.ml,
    azurerm_network_security_group.bas,
  azurerm_network_security_group.ml]
}

resource "azurerm_bastion_host" "bas" {
  name                = "gbj-ml-prod-bas"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name

  ip_configuration {
    name                 = "gbj-ml-prod-bas"
    subnet_id            = azurerm_subnet.bas.id
    public_ip_address_id = azurerm_public_ip.bas.id
  }

  depends_on = [azurerm_virtual_network.ml,
    azurerm_network_security_group.bas,
    azurerm_network_security_group.ml,
    azurerm_subnet_network_security_group_association.bas,
  azurerm_subnet_network_security_group_association.ml]
}