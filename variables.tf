variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for the network resources"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Existing resource group for this deployment"
  type        = string
  default     = "rg-azure-hub-spoke"
}

variable "admin_source_ip_cidr" {
  description = "Administrator public IPv4 address in CIDR notation, restricted to a single /32"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}[.]){3}[0-9]{1,3}/32$", var.admin_source_ip_cidr)) && can(cidrhost(var.admin_source_ip_cidr, 0))
    error_message = "Provide a valid administrator IPv4 address with a /32 prefix."
  }
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
    condition = length(var.admin_password) >= 16 &&
      can(regex("[A-Z]", var.admin_password)) &&
      can(regex("[a-z]", var.admin_password)) &&
      can(regex("[0-9]", var.admin_password)) &&
      can(regex("[^A-Za-z0-9]", var.admin_password))
    error_message = "Use a unique password with at least 16 characters, including uppercase and lowercase letters, a number, and a symbol."
  }
}

variable "vm_size" {
  description = "Size for the hub and all four spoke VMs; check Central India availability and subscription charges."
  type        = string
  default     = "Standard_B1s"
}
