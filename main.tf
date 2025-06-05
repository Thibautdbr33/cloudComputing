terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.77.0"
    }
  }

  backend "azurerm" {
    storage_account_name = "iacstorage974"             
    container_name       = "tfstate"                    
    key                  = "vm_deploy.tfstate"  # Ce nom peut rester fixe, ou être "vm_deploy-${var.env}.tfstate" si tu veux isoler les états
  }
}

provider "azurerm" {
  subscription_id            = var.subscription
  features {}
  skip_provider_registration = true
}

resource "azurerm_resource_group" "my_resource_group" {
  name     = "rg-iac-${var.env}"
  location = "francecentral"
}

resource "azurerm_virtual_network" "my_vnet" {
  name                = "vnet-iac-${var.env}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.my_resource_group.location
  resource_group_name = azurerm_resource_group.my_resource_group.name
}

resource "azurerm_subnet" "my_subnet" {
  name                 = "subnet-iac-${var.env}"
  resource_group_name  = azurerm_resource_group.my_resource_group.name
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_virtual_machine" "my_vm" {
  name                  = "vm-iac-${var.env}"
  resource_group_name   = azurerm_resource_group.my_resource_group.name
  location              = azurerm_resource_group.my_resource_group.location
  availability_set_id   = azurerm_availability_set.my_availability_set.id
  network_interface_ids = [azurerm_network_interface.my_nic.id]

  vm_size                        = "Standard_B1s"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202209200"
  }

  storage_os_disk {
    name              = "vm-iac-${var.env}-OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "vm-iac-${var.env}"
    admin_username = "adminuser"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_availability_set" "my_availability_set" {
  name                = "avset-iac-${var.env}"
  resource_group_name = azurerm_resource_group.my_resource_group.name
  location            = azurerm_resource_group.my_resource_group.location
}

resource "azurerm_network_interface" "my_nic" {
  name                = "nic-iac-${var.env}"
  location            = azurerm_resource_group.my_resource_group.location
  resource_group_name = azurerm_resource_group.my_resource_group.name
  depends_on          = [azurerm_subnet.my_subnet]

  ip_configuration {
    name                          = "nicconf-iac-${var.env}"
    subnet_id                     = azurerm_subnet.my_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
