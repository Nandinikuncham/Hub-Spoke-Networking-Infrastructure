# Azure Hub-and-Spoke Network Architecture

This project provisions five Ubuntu VMs in Central India: one public-facing jump VM in the hub and one private VM in each spoke. Each spoke has a private Standard load balancer for SSH access through the hub. Azure Monitor collects basic performance metrics for all five VMs.

## Network topology

```mermaid
flowchart LR
    Admin["Admin workstation - public IPv4 /32"] -->|SSH 22| PublicIP["Static Standard public IP"]
    PublicIP --> Jump["Hub management subnet 10.0.1.0/24 - Ubuntu VM - azureuser - password SSH - OS disk deleted with VM"]

    Jump -->|SSH 22| DevLB["Development internal LB - 10.1.1.10"]
    DevLB -->|TCP 22 - one backend| DevVM["Development subnet 10.1.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]
    Jump -->|SSH 22| TestLB["Testing internal LB - 10.2.1.10"]
    TestLB -->|TCP 22 - one backend| TestVM["Testing subnet 10.2.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]
    Jump -->|SSH 22| AppLB["Production app internal LB - 10.3.1.10"]
    AppLB -->|TCP 22 - one backend| AppVM["Production app subnet 10.3.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]
    Jump -->|SSH 22| DataLB["Production data internal LB - 10.4.1.10"]
    DataLB -->|TCP 22 - one backend| DataVM["Production data subnet 10.4.1.0/24 - private Ubuntu VM - OS disk deleted with VM"]

    Hub["Hub VNet 10.0.0.0/16"] ---|VNet peering| Jump
    Hub ---|VNet peering| DevLB
    Hub ---|VNet peering| TestLB
    Hub ---|VNet peering| AppLB
    Hub ---|VNet peering| DataLB

    Jump -.->|Performance metrics| AMA["Azure Monitor Linux Agent on all five VMs"]
    DevVM -.->|Performance metrics| AMA
    TestVM -.->|Performance metrics| AMA
    AppVM -.->|Performance metrics| AMA
    DataVM -.->|Performance metrics| AMA
    AMA --> DCR["Data collection rule - CPU, memory, disk"]
    DCR --> Workspace["Log Analytics workspace - 30-day retention"]
    Workspace --> Workbook["Hub-Spoke VM Health workbook"]
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

- **Connectivity:** Hub and spoke VNets communicate through VNet peering.
- **Public entry point:** Only the hub VM has a public IP. SSH is restricted to the administrator's current public IPv4 `/32`.
- **Password authentication:** All five Ubuntu VMs use the `azureuser` account and a password supplied locally through a sensitive Terraform variable. No SSH keys are configured. Use a new strong password; never commit it to GitHub.
- **Private spoke access:** Spoke VMs have no public IP. A Standard internal load balancer in each spoke provides a private TCP 22 frontend (`10.x.1.10`); connect to the frontend from the jump VM over hub-to-spoke peering. Each load balancer has one VM backend, so it does not provide distribution or VM failover. Spoke NSGs allow SSH from the hub management subnet and Azure load-balancer health probes.
- **Disk cleanup:** AzureRM is configured to delete managed OS disks when their VMs are deleted.
- **Monitoring:** Azure Monitor Linux Agent collects CPU, memory, and disk counters every 60 seconds. Log Analytics retains data for 30 days; ingestion and retention may incur charges. The workbook shows recent measurements and a one-hour trend.
- **Network routing:** Hub-to-spoke peering is direct; there is no Azure Firewall, forced tunneling, or direct spoke-to-spoke peering.
- **Costs:** Five running VMs, their managed disks, the Standard public IP, four Standard internal load balancers, and Log Analytics can incur charges. Free-trial coverage is not guaranteed.

Review access rules, the Terraform plan, and Azure costs before applying infrastructure.
