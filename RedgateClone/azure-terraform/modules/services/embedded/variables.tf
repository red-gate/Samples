variable "resource_group_name" {
  description = "The resource group name where all the resources will be stored"
  default = "redgate-clone"
}
variable "resource_group_location" {
  description = "Geographical lcoation (i.e. uksouth), where cluster needs to be created"
  default = "uksouth"
}
variable "vm_name" {
  description = "The name of the VM"
  default = "redgate-clone-vm"
}
variable "vm_username" {
  description = "The root user username"
  default = "cloneadmin"
}
variable "vm_password" {
  description = "The root user password"
}

variable "vm_size" {
  description = "The size of the VM"
  default = "Standard_E8s_v5"
}

variable "distro" {
  description = "The distribution of the VM image. Use `ubuntu` for Ubuntu 22.04 and `rhel` for Red Hat Enterprise Linux 9.2"
  default = "ubuntu"
}

variable "image_publisher" {
  type = map(string)
  description = "The storage image publisher"

  default = {
    ubuntu = "Canonical"
    rhel = "RedHat"
  }
}

variable "image_offer" {
  type =  map(string)
  description = "The storage image offer"

  default = {
    ubuntu = "0001-com-ubuntu-server-jammy"
    rhel = "RHEL"
  }
}

variable "image_sku" {
  type = map(string)
  description = "The storage image sku"

  default = {
    ubuntu = "22_04-lts"
    rhel = "9-lvm-gen2"
  }
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

variable "static_allowed_ips" {
  type = list(string)
  default = [
    # "12.34.56.78/32"          Add IP addresses that need access to the VM
  ]
}

locals {
  allowed_ips = concat(
    var.static_allowed_ips,
    [
      chomp(data.http.myip.response_body)
    ]
  )
}
