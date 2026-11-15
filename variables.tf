variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for the network resources"
  type        = string
  default     = "centralindia"
}

variable "connectivity_resource_group_name" {
  description = "Resource group for the hub network, firewall, Bastion, and VPN gateway"
  type        = string
  default     = "rg-hub-spoke-connectivity"
}

variable "identity_resource_group_name" {
  description = "Resource group for shared identity and monitoring services"
  type        = string
  default     = "rg-hub-spoke-identity"
}

variable "shared_data_resource_group_name" {
  description = "Resource group for the shared Azure SQL database and private DNS"
  type        = string
  default     = "rg-hub-spoke-shared-data"
}

variable "key_vault_name" {
  description = "Globally unique Azure Key Vault name"
  type        = string

  validation {
    condition     = length(var.key_vault_name) >= 3 && length(var.key_vault_name) <= 24 && can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.key_vault_name))
    error_message = "Use a globally unique 3-24 character Key Vault name with lowercase letters, numbers, and hyphens; start and end with a letter or number."
  }
}

variable "sql_server_name" {
  description = "Globally unique Azure SQL logical server name"
  type        = string

  validation {
    condition     = length(var.sql_server_name) >= 3 && length(var.sql_server_name) <= 63 && can(regex("^[a-z0-9-]+$", var.sql_server_name)) && !startswith(var.sql_server_name, "-") && !endswith(var.sql_server_name, "-")
    error_message = "Use a globally unique 3-63 character SQL server name with lowercase letters, numbers, and hyphens; do not start or end with a hyphen."
  }
}

variable "sql_database_name" {
  description = "Name of the new Azure SQL free-tier database"
  type        = string
  default     = "hubspoke-free-db"
}

variable "admin_username" {
  description = "Linux VM administrator username"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "New strong Linux VM password supplied locally via TF_VAR_admin_password; Terraform state contains this value in plain text."
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.admin_password) >= 16 &&
      can(regex("[A-Z]", var.admin_password)) &&
      can(regex("[a-z]", var.admin_password)) &&
      can(regex("[0-9]", var.admin_password)) &&
      can(regex("[^A-Za-z0-9]", var.admin_password))
    )
    error_message = "Use a unique password with at least 16 characters, including uppercase and lowercase letters, a number, and a symbol."
  }
}

variable "sql_admin_username" {
  description = "Administrator login for the Azure SQL logical server"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "New strong SQL server administrator password supplied locally via TF_VAR_sql_admin_password; Terraform state contains this value in plain text."
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.sql_admin_password) >= 16 &&
      can(regex("[A-Z]", var.sql_admin_password)) &&
      can(regex("[a-z]", var.sql_admin_password)) &&
      can(regex("[0-9]", var.sql_admin_password)) &&
      can(regex("[^A-Za-z0-9]", var.sql_admin_password))
    )
    error_message = "Use a unique password with at least 16 characters, including uppercase and lowercase letters, a number, and a symbol."
  }
}

variable "create_network_watcher" {
  description = "Set true only after confirming that no Network Watcher exists in the region; Azure allows one per subscription per region."
  type        = bool
  default     = false
}

variable "vm_size" {
  description = "Size for the three spoke VMs; check Central India availability, quotas, and charges."
  type        = string
  default     = "Standard_B1s"
}
