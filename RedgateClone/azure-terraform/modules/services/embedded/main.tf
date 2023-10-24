data "azurerm_resource_group" "rsg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "avn" {
  name                = "${var.vm_name}-vn"
  location            = data.azurerm_resource_group.rsg.location
  resource_group_name = data.azurerm_resource_group.rsg.name
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "asn" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = data.azurerm_resource_group.rsg.name
  virtual_network_name = azurerm_virtual_network.avn.name
  address_prefixes     = ["10.240.0.0/16"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.vm_name}-ip"
  resource_group_name = data.azurerm_resource_group.rsg.name
  location            = data.azurerm_resource_group.rsg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = data.azurerm_resource_group.rsg.location
  resource_group_name = data.azurerm_resource_group.rsg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.asn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = data.azurerm_resource_group.rsg.location
  resource_group_name   = data.azurerm_resource_group.rsg.name
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  # VM Size
  vm_size               = var.vm_size
  storage_image_reference {
    publisher =  var.image_publisher[var.distro]
    offer     =  var.image_offer[var.distro]
    sku       =  var.image_sku[var.distro]
    version   =  "latest"
  }

  # VM Config
  os_profile {
    computer_name  = var.distro
    admin_username = var.vm_username
    admin_password = var.vm_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  # OS Disk
  delete_os_disk_on_termination      = true
  storage_os_disk {
    name                      = "${var.vm_name}-os-disk"
    caching                   = "ReadWrite"
    create_option             = "FromImage"
    managed_disk_type         = "Premium_LRS"
    # Because the performance tier cannot be selected directly, a 512GiB disk has been chosen to provide sufficient
    # IOPS to avoid getting ETCD failures due to slow disk operations.
    disk_size_gb = "512"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo bash -c 'echo fs.inotify.max_user_instances=512 >> /etc/sysctl.conf'",
      "sudo bash -c 'echo fs.aio-max-nr=1048576 >> /etc/sysctl.conf'",
      "sudo sysctl -p /etc/sysctl.conf"
    ]
    connection {
      type          = "ssh"
      user          = var.vm_username
      password      = var.vm_password
      host          = azurerm_public_ip.public_ip.ip_address
    }  
  }

  tags = {
    environment = "development"
  }
}

resource "azurerm_managed_disk" "ceph-disk1" {
  name                 = "${var.vm_name}-disk1"
  location             = data.azurerm_resource_group.rsg.location
  resource_group_name  = data.azurerm_resource_group.rsg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1024"
}

resource "azurerm_virtual_machine_data_disk_attachment" "ceph-disk1" {
  managed_disk_id    = azurerm_managed_disk.ceph-disk1.id
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = "10"
  caching            = "ReadWrite"
}