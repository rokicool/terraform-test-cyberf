
variable "subscription_id" {}
variable "tenant_id" {}

variable "environment" {
  type = string
  description = "Something like test, dev or prod to add to the names of objects"
}


variable "project_id" {
  type = string
  description = "Just a substring to add to created objects to make them uniquie"
}

# Windows sql VM Admin User
variable "admin_username" {
  type        = string
  description = "Windows VM Admin User"
}

# Windows VM Admin Password
variable "admin_password" {
  type        = string
  description = "Windows VM Admin Password"
}


variable "sql_username" {
  type = string
  description = "The username of SQL admin user"
}

variable "sql_password" {
  type = string
  description = "The password of SQL admin user"
}

variable "ad_domain" {
  type = string
  description = "AD Domain name"
  default = "alwayson.azure"
}

variable "ad_domain_netbios" {
  type = string
  description = "AD Domain netbios name"
  default = "alwayson"
}

variable "ad_sql_ou_path" {
  type = string
  description = "OU Path of SQL Servers"
  #default = "OU=SQLServers,DC=alwayson,DC=azure"
  default = ""
}
