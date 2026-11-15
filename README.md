# Hub-Spoke-Networking-Infrastructure

Terraform project for an Azure hub-and-spoke network in Central India. It creates five Ubuntu VMs: one hub jump VM and one private VM in each spoke. Each spoke has a private Standard load balancer for SSH access through the hub.

## Architecture

See [architecture.md](./architecture.md) for the network diagram and access boundaries.

| Network | Address space | Subnet |
| --- | --- | --- |
| Hub | `10.0.0.0/16` | Management `10.0.1.0/24` |
| Development | `10.1.0.0/16` | `10.1.1.0/24` |
| Testing | `10.2.0.0/16` | `10.2.1.0/24` |
| Production app | `10.3.0.0/16` | `10.3.1.0/24` |
| Production data | `10.4.0.0/16` | `10.4.1.0/24` |

## What's included

- `main.tf` — hub, four spokes, subnets, NSGs, bidirectional hub peering, one public jump VM, and four private spoke VMs.
- `load_balancer.tf` — one Standard internal load balancer per spoke, with a private frontend and a TCP 22 probe/rule.
- `monitoring.tf` — Azure Monitor Linux Agent, performance data collection rule, Log Analytics workspace, and VM health workbook.
- `variables.tf` — network inputs, `azureuser`, sensitive password input, and input validation.
- `versions.tf` — Terraform and AzureRM provider requirements; managed OS disks are deleted with their VMs.
- `outputs.tf` — hub, spoke VM, and spoke load-balancer IPs plus monitoring workspace and workbook identifiers.
- `terraform.tfvars.example` — safe template; copy it to the ignored local `terraform.tfvars` and replace sample values.
- `.gitignore` — excludes Terraform state, local variables, and generated plans.
- `.github/workflows/terraform-validation.yml` — formatting and configuration validation on pushes and pull requests.

## Prerequisites

- Terraform 1.5 or later.
- Azure CLI and an Azure identity with Contributor access to the target resource group.
- An existing resource group named `rg-azure-hub-spoke` in Central India, or update the variable to an existing resource group.
- An administrator public IPv4 address to restrict inbound SSH to a single `/32`.

Authenticate to Azure and select your subscription:

```powershell
az login
az account set --subscription "102b28e5-3d71-4cfa-ab2e-49ea41e3d0ae"
```

## Configure and deploy from VS Code

From the repository folder in the VS Code PowerShell terminal:

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Edit the ignored `terraform.tfvars` and verify the provided subscription ID. Set your current public IPv4 address followed by `/32`; replace the documentation-only example IP.

Set a new, unique password locally. It must be at least 16 characters and include uppercase and lowercase letters, a number, and a symbol. Do not reuse the password previously shared in chat, and never put a password in GitHub or a checked-in `.tfvars` file:

```powershell
$securePassword = Read-Host "Enter a new strong VM password" -AsSecureString
$env:TF_VAR_admin_password = [System.Net.NetworkCredential]::new("", $securePassword).Password
```

Terraform marks the variable sensitive, but AzureRM stores VM administrator credentials in Terraform state in plain text. Keep state and plan files private, never commit or share them, and use a secured remote state backend for ongoing use.

Format, initialize, validate, and review the plan before applying:

```powershell
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Five `Standard_B1s` VMs are requested by default. Free-trial coverage is not guaranteed for five VMs; check regional availability, quotas, and projected charges in the Azure portal and plan. Apply only after reviewing the plan:

```powershell
terraform apply tfplan
Remove-Item Env:TF_VAR_admin_password
```

## Connect to the hub and spokes

From the administrator workstation, connect to the hub's public IP. SSH is permitted only from the configured administrator `/32`; enter the VM password when prompted:

```powershell
$hubIp = terraform output -raw jump_vm_public_ip
ssh "azureuser@$hubIp"
```

From the workstation, get the private frontend IP mapping for the spoke load balancers:

```powershell
terraform output -json spoke_lb_private_ips
```

On the hub jump VM, connect to a spoke through its internal load balancer using the matching private frontend IP (the frontends use `.10` in their respective spoke subnets):

```bash
ssh azureuser@<spoke-load-balancer-private-ip>
```

Each load balancer has one VM in its backend pool. It provides a private TCP 22 entry point, but does not distribute SSH sessions across multiple VMs or provide VM failover. The spoke NSGs allow the Azure load-balancer health probe as well as SSH from the hub management subnet. If your public IP changes, update the `/32` in `terraform.tfvars` and apply the change.

## VM monitoring dashboard

The Azure Monitor Linux Agent is configured on the hub and four spoke VMs. A data collection rule sends CPU, memory, and disk performance counters to the Log Analytics workspace every 60 seconds. The `Hub-Spoke VM Health` workbook includes a last-hour trend chart and a table of recent measurements. It does not include application or network metrics or alert rules.

After deployment and agent startup, open **Azure portal > Monitor > Workbooks** and select **Hub-Spoke VM Health**. Initial data may take several minutes to appear. The outputs `monitoring_workspace_name` and `monitoring_workbook_id` identify the monitoring resources:

```powershell
terraform output monitoring_workspace_name
terraform output monitoring_workbook_id
```

Log Analytics ingestion and retention can incur charges. Review workspace usage and current Azure pricing; free-trial eligibility does not guarantee that monitoring or all five VMs are free.

## Costs and cleanup

Running five VMs, their managed OS disks, the Standard public IP, four Standard internal load balancers, and Log Analytics ingestion/retention can incur charges; do not assume the Azure free trial covers every resource. The provider is configured to delete managed OS disks when their VMs are deleted. When finished with this lab, review the plan and run `terraform destroy`. The existing resource group itself is not managed by this configuration.
