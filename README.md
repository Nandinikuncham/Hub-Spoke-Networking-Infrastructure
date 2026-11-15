# Hub-Spoke-Networking-Infrastructure

A personal infrastructure-as-code project for building an Azure hub-and-spoke network in Central India. Terraform provisions a hub, four isolated spokes, bidirectional hub peering, network security groups, and a Linux jump VM reachable over a restricted public IP. No VPN is used.

## Architecture

See [architecture.md](./architecture.md) for the network diagram and access boundaries.

| Network | Address space | Subnet |
| --- | --- | --- |
| Hub | `10.0.0.0/16` | Management `10.0.1.0/24` |
| Development | `10.1.0.0/16` | `10.1.1.0/24` |
| Testing | `10.2.0.0/16` | `10.2.1.0/24` |
| Production app | `10.3.0.0/16` | `10.3.1.0/24` |
| Production data | `10.4.0.0/16` | `10.4.1.0/24` |

Only the jump VM has a public IP. SSH is restricted to the administrator's public IPv4 `/32` and uses an SSH public key. Spoke workloads are not created by this configuration.

## What's included

- `main.tf` — hub, spokes, subnets, NSGs, VNet peerings, public IP, NIC, and jump VM.
- `variables.tf` — deployment inputs, including validation that SSH source is one IPv4 `/32`.
- `versions.tf` — Terraform and AzureRM provider requirements.
- `outputs.tf` — network names and jump VM IP addresses.
- `terraform.tfvars.example` — safe template; copy it to the ignored local `terraform.tfvars` and replace the sample values.
- `.gitignore` — excludes Terraform state, local variables, and generated plans.
- `.github/workflows/terraform-validation.yml` — formatting and configuration validation on pushes and pull requests.

## Prerequisites

- Terraform 1.5 or later.
- Azure CLI and an Azure identity with Contributor access to the target resource group.
- An existing resource group named `rg-azure-hub-spoke` in Central India, or update the variable to an existing resource group.
- An SSH key pair. Keep the private key local; Terraform reads only the `.pub` file.

Authenticate interactively with Azure CLI (Terraform uses the CLI session):

```powershell
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

Do not put client secrets in `.tf` files, `.tfvars`, or GitHub. If using service-principal authentication instead, use a rotated secret injected through a secure environment/secret manager.

## Configure and deploy from VS Code

From the repository folder in the VS Code PowerShell terminal:

```powershell
ssh-keygen -t ed25519 -f "$HOME\.ssh\hub_spoke_ed25519"
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Edit `terraform.tfvars` and set:

- `subscription_id` to your Azure subscription ID.
- `admin_source_ip_cidr` to your current public IPv4 address followed by `/32` (for example `203.0.113.10/32` is documentation-only; replace it).
- `ssh_public_key_path` to the `.pub` key path on your computer.

Then format, initialize, validate, and review the plan:

```powershell
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
```

`terraform init` generates `.terraform.lock.hcl`; commit that lock file after initialization so provider versions are reproducible. Review all planned resources and costs before deploying. Apply only after confirming the plan:

```powershell
terraform apply tfplan
```

Connect from the permitted administrator address:

```powershell
ssh -i "$HOME\.ssh\hub_spoke_ed25519" "azureadmin@$(terraform output -raw jump_vm_public_ip)"
```

If your public IP changes, update the `/32` in `terraform.tfvars` and apply the change.

## Costs and cleanup

The Standard public IP and running VM can incur charges; VM size availability and quotas vary by region and subscription. When finished with this lab, review the plan and run `terraform destroy` to remove resources managed by this configuration. Terraform state is local and is intentionally excluded from Git; back it up securely if the deployment must be managed from another machine.
