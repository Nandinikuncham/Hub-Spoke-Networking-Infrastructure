# Azure Hub-Spoke Networking Case Study

Terraform configuration for a hub-and-spoke landing-zone example in Central India. The design has three workload spokes, shared identity/monitoring services, and a shared Azure SQL database reached through a private endpoint. It is intended for a networking case study; review the plan and all Azure costs before deploying.

## Architecture

See [architecture.md](./architecture.md) for the network diagram and traffic boundaries.

| Network | Address space | Subnet(s) |
| --- | --- | --- |
| Hub | `10.0.0.0/16` | AzureFirewallSubnet `10.0.1.0/26`; AzureBastionSubnet `10.0.2.0/26`; GatewaySubnet `10.0.3.0/27`; private endpoints `10.0.4.0/24` |
| Development | `10.1.0.0/16` | `10.1.1.0/24` |
| Testing | `10.2.0.0/16` | `10.2.1.0/24` |
| Production app | `10.3.0.0/16` | `10.3.1.0/24` |

The former Production Data VM/VNet and its load balancer are removed. A shared Azure SQL database replaces that workload.

## Resource groups and components

- **Connectivity RG:** hub VNet and dedicated subnets, Azure Firewall, Azure Bastion, VPN Gateway, private endpoint, and public IPs required by those services.
- **Identity RG:** RBAC-enabled Key Vault, Recovery Services vault, Log Analytics workspace, Azure Monitor data collection rule, and VM health workbook. Network Watcher creation is optional and disabled by default to avoid a duplicate regional resource.
- **Workload RGs:** one each for Development, Testing, and Production App. Each contains its spoke VNet/subnet, NSG, Ubuntu VM, and Standard internal SSH load balancer.
- **Shared Data RG:** Azure SQL logical server/database and the private DNS zone for SQL.
- **Shared database:** Azure SQL Database serverless free-tier settings are requested through the AzAPI provider, with the free limit enabled and exhaustion behavior set to AutoPause. Public SQL network access is disabled. A private endpoint is in the hub and private DNS is linked to the hub and all three spokes.

The Azure SQL administrator is configured for server administration only. This code does not grant application/database users or permissions. Set up the database identity and least-privilege grants separately before connecting an application.

## Access and traffic boundaries

- Use Azure Bastion to connect to spoke VM private IPs. The VMs have no public IPs. SSH password authentication is enabled for the `azureuser` account; NSGs allow SSH from the Bastion subnet and Azure load-balancer probes.
- The three internal load balancers expose private TCP port 22, each with one VM backend. They are optional private SSH front ends, not a path through Bastion and not a high-availability pool.
- The hub and each spoke have bidirectional VNet peering. Peering is direct: there are no UDRs or forced routes through the Firewall, and this configuration does not filter spoke traffic with the Firewall. Firewall rules are not configured.
- A VPN Gateway resource is created in the hub. No VPN connection, tunnel, or client configuration is included.
- The database is reachable only over its private endpoint. VNet peering and private DNS provide network reachability; they do not grant SQL login or database permissions.
- The Recovery Services vault is created as shared infrastructure; no VM backup policy or protected item is configured.

## Credentials and Terraform state

The VM username defaults to `azureuser`. Set new, unique VM and SQL administrator passwords locally; never place them in `terraform.tfvars`, Git, or chat. Do not reuse credentials that have been exposed previously.

In PowerShell, set the passwords for the current terminal session:

```powershell
$secureVmPassword = Read-Host "Enter a new strong VM password" -AsSecureString
$env:TF_VAR_admin_password = [System.Net.NetworkCredential]::new("", $secureVmPassword).Password
$secureSqlPassword = Read-Host "Enter a new strong SQL administrator password" -AsSecureString
$env:TF_VAR_sql_admin_password = [System.Net.NetworkCredential]::new("", $secureSqlPassword).Password
```

Terraform marks both values sensitive in CLI output, but Terraform state can still store them in plain text. Keep state and plans private; use a secured remote state backend for ongoing work. This configuration creates an empty Key Vault with RBAC enabled but does not copy either password into it.

## Prerequisites

- Terraform 1.5 or later, Azure CLI, and VS Code.
- Azure permissions at subscription scope to create resource groups and the resources in this project. The configuration creates Connectivity, Identity, Shared Data, and three workload resource groups.
- Check Central India service availability, subscription quota, and current pricing. Azure Firewall, Bastion, VPN Gateway, public IPs, load balancers, private endpoints, Log Analytics ingestion/retention, storage, and SQL usage can incur charges. The Azure SQL free-tier limits do not make the rest of the architecture free.

Sign in with your Azure CLI identity and select the target subscription:

```powershell
az login
az account set --subscription "102b28e5-3d71-4cfa-ab2e-49ea41e3d0ae"
```

No application client secret is needed when using Azure CLI authentication. Do not put service-principal credentials into checked-in files.

## Configure, review, and deploy

From the repository folder in the VS Code PowerShell terminal:

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Edit the ignored local `terraform.tfvars`. Keep the subscription ID correct, and replace the example Key Vault and SQL server names with globally unique names. Passwords are supplied only through the environment variables above.

Format, initialize, validate, and review the plan:

```powershell
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Only apply after reviewing every planned resource, permission, and charge:

```powershell
terraform apply tfplan
Remove-Item Env:TF_VAR_admin_password
Remove-Item Env:TF_VAR_sql_admin_password
```

After deployment, open **Azure portal > Bastion** on the hub Bastion host and connect to a spoke VM by private IP. The outputs `spoke_vm_private_ips`, `spoke_lb_private_ips`, `sql_server_fqdn`, `sql_database_name`, `monitoring_workspace_name`, and `monitoring_workbook_id` provide the corresponding resource details.

## Monitoring and Network Watcher

Azure Monitor Linux Agent and a data collection rule collect CPU, memory, and disk counters for the three VMs every 60 seconds. After the agents start sending data, open **Azure portal > Monitor > Workbooks > Hub-Spoke VM Health**. Initial measurements may take several minutes; Log Analytics usage can incur charges.

Azure permits one Network Watcher per subscription/region. The Terraform variable `create_network_watcher` defaults to `false`. Check for an existing watcher before changing it:

```powershell
az network watcher list --subscription "102b28e5-3d71-4cfa-ab2e-49ea41e3d0ae" --output table
```

Set `create_network_watcher = true` only if no watcher exists in Central India. If one already exists, leave this setting false unless you intentionally import the existing resource into Terraform state.

## Destroy and cleanup

There is no separate Terraform destroy file. Terraform destroys resources recorded in the current state with:

```powershell
terraform plan -destroy
terraform destroy
```

The resource groups are Terraform-managed, so destroying the configuration removes the managed resources and those groups. Review the destroy plan first and preserve any data you need. The AzureRM provider is configured to delete VM OS disks when VMs are deleted.
