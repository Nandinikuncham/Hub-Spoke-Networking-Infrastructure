# Azure Hub-and-Spoke Network Architecture

This project provisions five Ubuntu VMs in Central India: one public-facing jump VM in the hub and one private VM in each spoke. No VPN is used.

## Network topology

```mermaid
flowchart TB
    admin["Administrator workstation<br/>Public IPv4 /32"]
    publicip["Static Standard Public IP"]

    subgraph rg["Resource group: rg-azure-hub-spoke · Central India"]
        subgraph hub["Hub VNet · 10.0.0.0/16"]
            hubvnet["Hub network"]
            subgraph management["Management subnet · 10.0.1.0/24"]
                jump["Ubuntu jump VM · azureuser<br/>Password-based SSH · public IP"]
                hubnsg["Hub NSG<br/>Allow TCP/22 from admin /32"]
                hubdisk["Managed OS disk<br/>Deleted with VM"]
            end
        end
        subgraph development["Development spoke · 10.1.0.0/16"]
            devvnet["VNet"]
            devsubnet["snet-development · 10.1.1.0/24"]
            devvm["Ubuntu VM · private IP<br/>SSH allowed from hub subnet"]
            devdisk["Managed OS disk<br/>Deleted with VM"]
        end
        subgraph testing["Testing spoke · 10.2.0.0/16"]
            testvnet["VNet"]
            testsubnet["snet-testing · 10.2.1.0/24"]
            testvm["Ubuntu VM · private IP<br/>SSH allowed from hub subnet"]
            testdisk["Managed OS disk<br/>Deleted with VM"]
        end
        subgraph production_app["Production app spoke · 10.3.0.0/16"]
            appvnet["VNet"]
            appsubnet["snet-prod-app · 10.3.1.0/24"]
            appvm["Ubuntu VM · private IP<br/>SSH allowed from hub subnet"]
            appdisk["Managed OS disk<br/>Deleted with VM"]
        end
        subgraph production_data["Production data spoke · 10.4.0.0/16"]
            datavnet["VNet"]
            datasubnet["snet-prod-data · 10.4.1.0/24"]
            datavm["Ubuntu VM · private IP<br/>SSH allowed from hub subnet"]
            datadisk["Managed OS disk<br/>Deleted with VM"]
        end
    end

    admin -->|"SSH TCP/22 · admin /32"| publicip
    publicip -->|"NIC association"| jump
    hubnsg -.-> jump
    jump --- hubdisk
    hubvnet <-->|"VNet peering"| devvnet
    hubvnet <-->|"VNet peering"| testvnet
    hubvnet <-->|"VNet peering"| appvnet
    hubvnet <-->|"VNet peering"| datavnet
    jump -->|"SSH to private IP"| devvm
    jump -->|"SSH to private IP"| testvm
    jump -->|"SSH to private IP"| appvm
    jump -->|"SSH to private IP"| datavm
    devvm --- devdisk
    testvm --- testdisk
    appvm --- appdisk
    datavm --- datadisk
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
