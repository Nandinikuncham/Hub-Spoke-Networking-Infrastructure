# Azure Hub-and-Spoke Network Architecture

This project provisions five Ubuntu VMs in Central India: one public-facing jump VM in the hub and one private VM in each spoke. No VPN is used.

## Network topology

```mermaid
flowchart LR
    Admin["Admin workstation - public IPv4 /32"] -->|SSH 22| PublicIP["Static Standard public IP"]
    PublicIP --> Jump["Hub management subnet 10.0.1.0/24 - Ubuntu VM - azureuser - password SSH - OS disk deleted with VM"]
    Jump -->|SSH to private IP| DevVM["Development subnet 10.1.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]
    Jump -->|SSH to private IP| TestVM["Testing subnet 10.2.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]
    Jump -->|SSH to private IP| AppVM["Production app subnet 10.3.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]
    Jump -->|SSH to private IP| DataVM["Production data subnet 10.4.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]
    Hub["Hub VNet 10.0.0.0/16"] --- Jump
    Hub --- Dev["Development VNet 10.1.0.0/16"]
    Hub --- Test["Testing VNet 10.2.0.0/16"]
    Hub --- App["Production app VNet 10.3.0.0/16"]
    Hub --- Data["Production data VNet 10.4.0.0/16"]
```

## Network address plan

| Network | Address space | Subnet |
| --- | --- | --- |
| Hub | `10.0.0.0/16` | Management `10.0.1.0/24` |
| Development | `10.1.0.0/16` | `10.1.1.0/24` |
| Testing | `10.2.0.0/16` | `10.2.1.0/24` |
| Production app | `10.3.0.0/16` | `10.3.1.0/24` |
| Production data | `10.4.0.0/16` | `10.4.1.0/24` |

## Access and boundaries

- **No VPN:** No VPN gateway or connection is deployed.
- **Public entry point:** Only the hub VM has a public IP. SSH is restricted to the administrator's current public IPv4 `/32`.
- **Password authentication:** All five Ubuntu VMs use the `azureuser` account and a password supplied locally through a sensitive Terraform variable. No SSH keys are configured. Use a new strong password; never commit it to GitHub.
- **Private spoke access:** Spoke VMs have no public IP. Their NSGs allow SSH only from the hub management subnet; connect to them from the jump VM over hub-to-spoke peering.
- **Disk cleanup:** AzureRM is configured to delete managed OS disks when their VMs are deleted.
- **No firewall or spoke-to-spoke peering:** Hub-to-spoke peering is direct. There is no Azure Firewall, forced tunneling, VPN, or direct spoke-to-spoke peering.
- **Costs:** Five running VMs, their managed disks, and the Standard public IP can incur charges. Free-trial coverage is not guaranteed.

Review access rules, the Terraform plan, and Azure costs before applying infrastructure.
