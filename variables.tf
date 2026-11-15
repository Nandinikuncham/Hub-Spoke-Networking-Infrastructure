variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
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
    condition     = can(cidrhost(var.admin_source_ip_cidr, 0)) && endswith(var.admin_source_ip_cidr, "/32")
    error_message = "Provide a valid administrator IPv4 address with a /32 prefix."
  }
}

variable "ssh_public_key_path" {
  description = "Local path to the SSH public key file"
  type        = string
}

variable "admin_username" {
  description = "Linux VM administrator username"
  type        = string
  default     = "azureadmin"
}

variable "vm_size" {
  description = "Jump VM size"
  type        = string
  default     = "Standard_B1s"
}
