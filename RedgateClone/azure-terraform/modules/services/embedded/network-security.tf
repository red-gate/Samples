resource "azurerm_subnet_network_security_group_association" "nsgassoc" {
  subnet_id                 = azurerm_subnet.asn.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  location            = data.azurerm_resource_group.rsg.location
  resource_group_name = data.azurerm_resource_group.rsg.name
}

resource "azurerm_network_security_rule" "netrule_outbound" {
  name                        = "${var.vm_name}-outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "netrule_icmp" {
  count                       = length(local.allowed_ips)
  name                        = "${var.vm_name}-icmp-${count.index}"
  priority                    = 100 + count.index
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = element(local.allowed_ips, count.index)
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "netrule_ssh" {
  count                       = length(local.allowed_ips)
  name                        = "${var.vm_name}-ssh-${count.index}"
  priority                    = 120 + count.index
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = element(local.allowed_ips, count.index)
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "netrule_kubeapi" {
  count                       = length(local.allowed_ips)
  name                        = "${var.vm_name}-kubeapi-${count.index}"
  priority                    = 130 + count.index
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefix       = element(local.allowed_ips, count.index)
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "netrule_admin_console" {
  count                       = length(local.allowed_ips)
  name                        = "${var.vm_name}-admin-${count.index}"
  priority                    = 140 + count.index
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8800"
  source_address_prefix       = element(local.allowed_ips, count.index)
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "netrule_api" {
  name                        = "${var.vm_name}-api"
  priority                    = 160
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8132"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "netrule_containers" {
  name                        = "${var.vm_name}-containers"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "32767-60000"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Allow rg-clone to download images from itself
# This is required because we access the kubernetes-hosted internal container registry via its FQDN so that we can use SSL to secure the registry.
# As a result of this, the network traffic from the node (host vm) to the registry (internal to Kubernetes) appears to come from the public ip of the VM.
resource "azurerm_network_security_rule" "registry_self_external" {
  name                        = "registry-self-external"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9632"
  source_address_prefix       = azurerm_public_ip.public_ip.ip_address   # This works for Statically allocated public_ip objects
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}
