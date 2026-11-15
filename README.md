# Azure Hub-Spoke Networking Case Study

Terraform configuration for a Central India hub-and-spoke landing zone with three workload spokes, shared Key Vault, monitoring, and backup services, and a private Azure SQL Database. This is a case-study project; no Azure resources have been deployed from this change. Review the plan, quotas, and current Azure costs before deploying.

## Architecture

See [architecture.md](./architecture.md) for the network diagram and traffic boundaries.

| Network | Address space | Subnet(s) |
| --- | --- | --- |
| Hub | `10.0.0.0/16` | AzureFirewallSubnet `10.0.1.0/26`; AzureBastionSubnet `10.0.2.0/26`; GatewaySubnet `10.0.3.0/27`; Key Vault private endpoints `10.0.4.0/24` |
| Development | `10.1.0.0/16` | VM `10.1.1.0/24`; SQL private endpoint `10.1.2.0/24` |
| Testing | `10.2.0.0/16` | VM `10.2.1.0/24`; SQL private endpoint `10.2.2.0/24` |
| Production app | `10.3.0.0/16` | VM `10.3.1.0/24`; SQL private endpoint `10.3.2.0/24` |

The former Production Data VM/VNet and its load balancer are replaced by Azure SQL Database in a dedicated Database Resource Group. There are three spoke VMs, with no Hub VM.

## Resource groups and services

- **Connectivity Resource Group:** hub VNet, Firewall, Bastion, VPN Gateway and their public IPs, plus the private endpoint for Key Vault.
- **Monitoring and Backup Resource Group (Terraform Identity Resource Group):** Key Vault, Key Vault private DNS zone, Log Analytics workspace, Azure Monitor data collection rule and workbook, Recovery Services vault and VM backup policy. Network Watcher creation is optional and disabled by default.
- **Development Resource Group Spoke, Testing Resource Group Spoke, Production App Resource Group Spoke:** each workload VNet/subnet, NSG, private Ubuntu VM, SQL private endpoint subnet, and internal SSH load balancer.
- **Database Resource Group:** Azure SQL logical server/database and three SQL private endpoint resources, one attached to each spoke's private endpoint subnet. Each spoke has its own private DNS zone so it resolves only its local SQL endpoint.

The Monitoring and Backup Resource Group label is for clarity; Terraform's `identity_resource_group_name` variable and Azure resource names remain unchanged. SQL public network access is disabled. The SQL DNS zones are linked only to their corresponding spokes, not the hub. Each endpoint subnet allows TCP 1433 from its local spoke address space and denies other VNet sources, including the hub. This keeps SQL access private and workload-specific without relying on spoke-to-spoke routing.

The Key Vault private endpoint is in the hub. Its private DNS zone is linked to the hub and all three spokes, so each workload can resolve the private vault address. VNet peering supplies network reachability; it does not grant data-plane permissions.

The Recovery Services vault protects the three spoke VMs with daily backups retained for 30 days. Azure SQL uses Azure-managed standard backups only; SQL is not protected by the Recovery Services vault and no long-term retention policy is configured.

## Access and traffic boundaries

- Spoke VMs have private IPs only. Use Azure Bastion to connect to their private IPs. SSH password authentication is enabled for the `azureuser` account; NSGs allow SSH from the Bastion subnet and Azure load-balancer probes.
- Each spoke has an internal TCP 22 load balancer with one VM backend. These are private SSH front ends, not a high-availability pool.
- The hub and each spoke have bidirectional VNet peering. Peering is direct: there are no UDRs or forced routes through the Firewall, and the Firewall does not filter direct spoke traffic. Firewall rules are not configured.
- A VPN Gateway resource is provisioned in the hub; a VPN connection requires its own configuration.
- The SQL logical server has public network access disabled. SQL private endpoints and per-spoke DNS provide connectivity only to the workload spokes. Database users and least-privilege permissions must still be configured separately.

## Credentials and Terraform state

The VM username defaults to `azureuser`. Set new, unique VM and SQL administrator passwords locally; never place them in `terraform.tfvars`, Git, or chat. Do not reuse credentials that were exposed previously.

In PowerShell, set passwords for the current terminal session:

```powershell
$secureVmPassword = Read-Host "Enter a new strong VM password" -AsSecureString
$env:TF_VAR_admin_password = [System.Net.NetworkCredential]::new("", $secureVmPassword).Password
$secureSqlPassword = Read-Host "Enter a new strong SQL administrator password" -AsSecureString
$env:TF_VAR_sql_admin_password = [System.Net.NetworkCredential]::new("", $secureSqlPassword).Password
```

Terraform marks both values sensitive in CLI output, but Terraform state can still store them in plain text. Keep state and plans private; use a secured remote state backend for ongoing work. The Key Vault is RBAC-enabled, but this configuration does not store either password in it.

## Prerequisites

- Terraform 1.5 or later, Azure CLI, and VS Code.
- Azure permissions at subscription scope to create resource groups and the configured resources.
- Check Central India service availability, subscription quota, and current pricing. Firewall, Bastion, VPN Gateway, public IPs, load balancers, private endpoints, VM backups, SQL metric ingestion, Log Analytics retention, and SQL usage can incur charges. The Azure SQL free-tier limits do not make the rest of the architecture free.

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

Edit the ignored local `terraform.tfvars`. Keep the subscription ID correct, and replace the example Key Vault and SQL server names with globally unique names. Supply passwords only through the environment variables above.

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

After deployment, use **Azure portal > Bastion** on the hub Bastion host to connect to a spoke VM by private IP. Outputs include `spoke_vm_private_ips`, `spoke_lb_private_ips`, `sql_server_fqdn`, `sql_database_name`, `monitoring_workspace_name`, and `monitoring_workbook_id`.

## Monitoring, backups, and Network Watcher

Azure Monitor Linux Agent and a data collection rule collect CPU, memory, and disk counters for the three VMs every 60 seconds. A SQL diagnostic setting streams Basic database metrics to the same Log Analytics workspace. After data arrives, open **Azure portal > Monitor > Workbooks > Hub-Spoke VM Health** for VM and SQL performance charts. Initial measurements may take several minutes; Log Analytics ingestion can incur charges.

The Recovery Services vault backs up each spoke VM daily at 23:00 UTC and retains 30 daily recovery points. Azure SQL uses Azure-managed standard backups; it is not included in the VM backup policy.

Azure permits one Network Watcher per subscription/region. `create_network_watcher` defaults to `false`. Check for an existing watcher before changing it:

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

Review the destroy plan first and preserve any data you need. The AzureRM provider is configured to delete VM OS disks when VMs are deleted.
