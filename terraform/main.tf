provider "azurerm" {
  features {}

  subscription_id = "751651ed-a544-4a3f-83b2-2289332c10bd"
}

resource "azurerm_resource_group" "kafka-zookeeper-rg" {
  name     = "kafka-zookeeper-rg"
  location = "Central India"
}

resource "azurerm_virtual_network" "kafka-zookeeper-virtual-network" {
  name                = "kafka-zookeeper-virtual-network"
  resource_group_name = azurerm_resource_group.kafka-zookeeper-rg.name
  location            = azurerm_resource_group.kafka-zookeeper-rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "kafka-zookeeper-subnet" {
  name                 = "kafka-zookeeper-subnet"
  resource_group_name  = azurerm_resource_group.kafka-zookeeper-rg.name
  virtual_network_name = azurerm_virtual_network.kafka-zookeeper-virtual-network.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_network_security_group" "kafka-zookeeper-sg" {
  name                = "ssh_nsg"
  location            = azurerm_resource_group.kafka-zookeeper-rg.location
  resource_group_name = azurerm_resource_group.kafka-zookeeper-rg.name

  security_rule {
    name                       = "allow_ssh_sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_zookeeper_sg"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2181"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_kafka9000_sg"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_kafka9091_sg"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9091"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_kafka9092_sg"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9092"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}



resource "azurerm_network_interface" "kafka-nic" {
  count               = 3
  name                = "kafka-nic${count.index}"
  location            = azurerm_resource_group.kafka-zookeeper-rg.location
  resource_group_name = azurerm_resource_group.kafka-zookeeper-rg.name

  ip_configuration {
    name                          = "kafka-ip-config"
    subnet_id                     = azurerm_subnet.kafka-zookeeper-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_virtual_machine" "kafka" {
  count                 = 3
  name                  = "kafka${count.index}"
  location              = azurerm_resource_group.kafka-zookeeper-rg.location
  resource_group_name   = azurerm_resource_group.kafka-zookeeper-rg.name
  vm_size               = "Standard_B1s"
  network_interface_ids = [element(azurerm_network_interface.kafka-nic.*.id, count.index)]
  delete_data_disks_on_termination = true

  
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "kafkadisk${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "kafka${count.index}"
    admin_username = "kafkauser"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/kafkauser/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

}

output "kafka_ips" {
  value = [for i in azurerm_network_interface.kafka-nic : i.private_ip_address]
}


resource "azurerm_public_ip" "zookeeper1_public_ip" {
  name                = "zookeeper1PublicIP"
  location            = azurerm_resource_group.kafka-zookeeper-rg.location
  resource_group_name = azurerm_resource_group.kafka-zookeeper-rg.name
  allocation_method   = "Dynamic"
}


resource "azurerm_network_interface" "zookeeper-nic" {
  name                = "zookeeper-nic"
  location            = azurerm_resource_group.kafka-zookeeper-rg.location
  resource_group_name = azurerm_resource_group.kafka-zookeeper-rg.name

  ip_configuration {
    name                          = "zookeeper-ip-config"
    subnet_id                     = azurerm_subnet.kafka-zookeeper-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.zookeeper1_public_ip.id
  }
}


resource "azurerm_virtual_machine" "zookeeper1" {
  name                  = "zookeeper1"
  location              = azurerm_resource_group.kafka-zookeeper-rg.location
  resource_group_name   = azurerm_resource_group.kafka-zookeeper-rg.name
  network_interface_ids = [azurerm_network_interface.zookeeper-nic.id,]
  vm_size               = "Standard_B1s"
  delete_data_disks_on_termination = true
  
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "zookeeperdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "zookeeper1"
    admin_username = "zookeeperuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/zookeeperuser/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }
}

output "zookeeper_ip" {
  value = azurerm_network_interface.zookeeper-nic.private_ip_address
}


output "zookeeper1_public_ip" {
  description = "The public IP of the Zookeeper VM"
  value       = azurerm_public_ip.zookeeper1_public_ip.ip_address
}






