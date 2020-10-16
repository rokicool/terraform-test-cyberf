
# Configure the Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  features {}
}


/* -----------------------------------------------------------------------
-
Storage accout for the Cloud Witness 
-
*/

resource "azurerm_resource_group" "rgp-witness" {
  name     = "rgp-east-${var.project_id}-${var.environment}"
  location = "East US"

   tags = {
    environment = var.environment
  }
}

resource "azurerm_storage_account" "witness-storage-account" {
  name                     = "saeast2${var.project_id}${var.environment}"
  resource_group_name      = azurerm_resource_group.rgp-witness.name
  location                 = azurerm_resource_group.rgp-witness.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.environment
  }
}



/* -----------------------------------------------------------------------
-
Discover resources in current 'prod' RG in East US2
-
*/

data "azurerm_resource_group" "resource-group-prod" {
  name = "rgp-eastus2-projectx-prod2"
}

data "azurerm_virtual_network" "vnet_left" {
  
  name                = "vnet-projectx-prod2"
  resource_group_name = data.azurerm_resource_group.resource-group-prod.name 
}

data "azurerm_subnet" "def-subnet-left" {

  name                = "WebSubnet"
  resource_group_name = data.azurerm_resource_group.resource-group-prod.name
  virtual_network_name = data.azurerm_virtual_network.vnet_left.name
}

data "azurerm_network_security_group" "nsg-sql-win" {
  name = "nsg-sql-windows-vm-projectx-prod2"
  resource_group_name = data.azurerm_resource_group.resource-group-prod.name
}

data "azurerm_network_security_group" "nsg-web-win" {
  name = "nsg-web-windows-vm-projectx-prod2"
  resource_group_name = data.azurerm_resource_group.resource-group-prod.name
}

/* -----------------------------------------------------------------------
-
Make RG in East US2 for VMs
-
*/

resource "azurerm_resource_group" "resource-group-left" {
  name     = "rgp-eastus2-${var.project_id}-${var.environment}"
  location = "East US2"
}


# Create Network Security Group to Access Win VM left from Internet
resource "azurerm_network_security_group" "nsg-win-vm-left" {
  name                = "nsg-win-vm-left-${var.project_id}-${var.environment}"
  location            = azurerm_resource_group.resource-group-left.location
  resource_group_name = azurerm_resource_group.resource-group-left.name

  security_rule {
    name                       = "allow-rdp"
    description                = "allow-rdp from any internal network"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*" 
  }

security_rule {
    name                       = "allow-rdp-chicago-roki"
    description                = "allow-rdp-chicago-roki"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "76.229.200.36/32"
    destination_address_prefix = "*" 
  }


  tags = {
   # application = var.app_name
    environment = var.environment 
  }
}


# Create Network Security Group to Access Web VM left from Internet
resource "azurerm_network_security_group" "nsg-win-vm-web-left" {
  name                = "nsg-win-vm-web-left-${var.project_id}-${var.environment}"
  location            = azurerm_resource_group.resource-group-left.location
  resource_group_name = azurerm_resource_group.resource-group-left.name

  security_rule {
    name                       = "allow-rdp"
    description                = "allow-rdp from any internal network"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*" 
  }

security_rule {
    name                       = "allow-rdp-chicago-roki"
    description                = "allow-rdp-chicago-roki"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "76.229.200.36/32"
    destination_address_prefix = "*" 
  }


  tags = {
   # application = var.app_name
    environment = var.environment 
  }
}


# Create Network Security Group to Access Web VM left from Internet
resource "azurerm_network_security_group" "nsg-win-vm-sql-left" {
  name                = "nsg-win-vm-sql-left-${var.project_id}-${var.environment}"
  location            = azurerm_resource_group.resource-group-left.location
  resource_group_name = azurerm_resource_group.resource-group-left.name

  security_rule {
    name                       = "allow-rdp"
    description                = "allow-rdp from any internal network"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*" 
  }

security_rule {
    name                       = "allow-rdp-chicago-roki"
    description                = "allow-rdp-chicago-roki"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "76.229.200.36/32"
    destination_address_prefix = "*" 
  }


  tags = {
   # application = var.app_name
    environment = var.environment 
  }
}


# AD DC in Azure
module "win-vm-addc-left" {
  source = "./win-vm-addc"

  vm_name     = "win-left"
  vm_rg_name  = azurerm_resource_group.resource-group-left.name 
  vm_location = azurerm_resource_group.resource-group-left.location
  vm_subnet_id= data.azurerm_subnet.def-subnet-left.id
  vm_storage_type = "StandardSSD_LRS"
  environment = var.environment
  vm_size     = "Standard_B2s"
  project_id  = var.project_id
  admin_username = var.admin_username
  admin_password = var.admin_password
  network_security_group_id = azurerm_network_security_group.nsg-win-vm-left.id
  
  dns_servers    = [ "10.60.1.254", "10.51.2.254"]

  vm_private_ip_address = "10.60.1.254"
  active_directory_domain = var.ad_domain
  active_directory_netbios_name = var.ad_domain_netbios
  ad_create = true
}

# Web Server in Azure
module "win-vm-web-left" {
  source = "./win-vm"

  vm_name     = "win-vm-web-left"
  vm_rg_name  = azurerm_resource_group.resource-group-left.name 
  vm_location = azurerm_resource_group.resource-group-left.location
  vm_subnet_id= data.azurerm_subnet.def-subnet-left.id
  vm_storage_type = "StandardSSD_LRS"
  environment = var.environment
  vm_size     = "Standard_B2s"
  project_id  = var.project_id
  admin_username = var.admin_username
  admin_password = var.admin_password
  network_security_group_id = azurerm_network_security_group.nsg-win-vm-web-left.id
  
  dns_servers    = [ "10.60.1.254", "10.51.2.254"]

}

# SQL Server in Azure

module "win-vm-sql-left" {
  depends_on=[module.win-vm-addc-left]  
  source = "./win-vm-sql"

  win_vm_sql_name  = "win-vm-sql-left"
  vm_rg_name       = azurerm_resource_group.resource-group-left.name 
  vm_location      = azurerm_resource_group.resource-group-left.location
  vm_subnet_id     = data.azurerm_subnet.def-subnet-left.id
  environment      = var.environment

  vm_storage_type  = "StandardSSD_LRS"

  os_image_publisher = "MicrosoftSQLServer"
  os_image_offer   = "SQL2017-WS2016"
  os_image_sku     = "SQLDEV"
  os_image_version = "latest"

  sql_username = var.sql_username
  sql_password = var.sql_password

  os_profile_windows_timezone = "Pacific Standard Time"

  vm_size     = "Standard_B2ms"
  project_id  = var.project_id

  dns_servers    = ["10.60.1.254", "10.51.2.254"]

  admin_username = var.admin_username
  admin_password = var.admin_password
  network_security_group_id = azurerm_network_security_group.nsg-win-vm-sql-left.id

  active_directory_domain = var.ad_domain
  active_directory_oupath = var.ad_sql_ou_path
}


/* -----------------------------------------------------------------------
-
Outputs
-
*/

# ADDC VM Public IP
output "win-vm-addc-left_public_ip" {
  value = module.win-vm-addc-left.win_vm_public_ip
}

# WEB VM Public IP
output "win-vm-web-left-left_public_ip" {
  value = module.win-vm-web-left.win_vm_public_ip
}

# SQL VM Public IP
output "win-vm-sql-left_public_ip" {
  value = module.win-vm-sql-left.win_vm_public_ip
}

#
output "witness-storage-account-key" {
  value = azurerm_storage_account.witness-storage-account.primary_access_key
}

#
output "witness-storage-account-primary_blob_connection_string" {
  value = azurerm_storage_account.witness-storage-account.primary_blob_connection_string
}