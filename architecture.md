# Azure Hub-and-Spoke Network Architecture

Proposed topology for `Hub-Spoke-Networking-Infrastructure` in Central India, based on the project's Terraform notes and the referenced [Azure Landing Zone hub-spoke pattern](https://github.com/shekhar1414/Azure-Landing-Zone-Terraform#network-topology-diagram).

## Network topology

```mermaid
flowchart TB
    admin["Administrator workstation<br/>Public IPv4 /32"]
    publicip["Static Standard Public IP"]

    subgraph rg["Existing resource group: rg-azure-hub-spoke · Central India"]
        subgraph hub["Hub VNet · vnet-hub-centralindia · 10.0.0.0/16"]
            subgraph management["Management subnet · 10.0.1.0/24"]
                jump["Linux jump VM<br/>SSH key authentication"]
                hubnsg["Hub NSG<br/>Allow TCP/22 from admin /32"]
            end
        end
        subgraph prodapp["Production app spoke · vnet-spoke-prod-app · 10.1.0.0/16"]
            appsubnet["snet-prod-app · 10.1.1.0/24<br/>Spoke NSG"]
        end
        subgraph proddata["Production data spoke · vnet-spoke-prod-data · 10.2.0.0/16"]
            datasubnet["snet-prod-data · 10.2.1.0/24<br/>Spoke NSG"]
        end
        subgraph development["Development spoke · vnet-spoke-development · 10.3.0.0/16"]
            devsubnet["snet-development · 10.3.1.0/24<br/>Spoke NSG"]
        end
        subgraph testing["Testing spoke · vnet-spoke-testing · 10.4.0.0/16"]
            testsubnet["snet-testing · 10.4.1.0/24<br/>Spoke NSG"]
        end
    end

    admin -->|"SSH TCP/22 · source restricted to admin /32"| publicip
    publicip -->|"NIC association"| jump
    hubnsg -.-> jump
    jump <-->|"VNet peering"| appsubnet
    jump <-->|"VNet peering"| datasubnet
    jump <-->|"VNet peering"| devsubnet
    jump <-->|"VNet peering"| testsubnet
```

## Access and boundaries

- **No VPN:** No VPN gateway or VPN connection is included.
- **Public entry:** The jump VM is the only resource with a public IP. SSH is intended to be restricted to the administrator's current public IPv4 `/32` and use SSH key authentication.
- **Private spoke access:** Spoke workloads can be reached from the jump VM over hub-to-spoke VNet peerings. Spoke NSGs allow SSH from the hub management subnet; other virtual-network inbound traffic is denied by the supplied rules.
- **No workload VMs yet:** The supplied Terraform provisions the networks and jump VM, but no spoke workload VMs.
- **No central firewall or forced tunneling:** The supplied Terraform does not include Azure Firewall or route tables. Spoke-to-spoke traffic is not directly peered.
- **Public IP changes:** Update the SSH source CIDR when the administrator's public IP changes.

This is a design reference, not a deployment approval. Review the Terraform plan, access rules, and Azure costs before applying infrastructure.
