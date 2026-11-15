locals {
  monitoring_vm_ids = {
    for name, vm in azurerm_linux_virtual_machine.spoke : name => vm.id
  }
}

resource "azurerm_log_analytics_workspace" "vm_monitoring" {
  name                = "law-hub-spoke-vm-monitoring"
  location            = var.location
  resource_group_name = azurerm_resource_group.identity.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "sql_database" {
  name                       = "sql-basic-metrics-to-workspace"
  target_resource_id         = azapi_resource.sql_database.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vm_monitoring.id

  enabled_metric {
    category = "Basic"
  }
}

resource "azurerm_monitor_data_collection_rule" "linux_performance" {
  name                = "dcr-hub-spoke-linux-performance"
  location            = var.location
  resource_group_name = azurerm_resource_group.identity.name
  kind                = "Linux"
  description         = "Collect CPU, memory, and disk usage from the three spoke Linux VMs."

  destinations {
    log_analytics {
      name                  = "vm-monitoring-workspace"
      workspace_resource_id = azurerm_log_analytics_workspace.vm_monitoring.id
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["vm-monitoring-workspace"]
  }

  data_sources {
    performance_counter {
      name                          = "linux-performance-counters"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(*)\\% Processor Time",
        "\\Memory(*)\\% Used Memory",
        "\\Logical Disk(*)\\% Used Space",
      ]
    }
  }
}

resource "azurerm_virtual_machine_extension" "azure_monitor_linux_agent" {
  for_each = local.monitoring_vm_ids

  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = each.value
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  settings                   = "{}"
}

resource "azurerm_monitor_data_collection_rule_association" "linux_vms" {
  for_each = local.monitoring_vm_ids

  name                    = "dcr-${replace(each.key, "_", "-")}"
  target_resource_id      = each.value
  data_collection_rule_id = azurerm_monitor_data_collection_rule.linux_performance.id

  depends_on = [azurerm_virtual_machine_extension.azure_monitor_linux_agent]
}

resource "azurerm_application_insights_workbook" "vm_health" {
  name                = "a673b551-40f3-4f90-bd7f-7a8a73c118d9"
  resource_group_name = azurerm_resource_group.identity.name
  location            = var.location
  display_name        = "Hub-Spoke VM Health"
  category            = "workbook"
  source_id           = lower(azurerm_log_analytics_workspace.vm_monitoring.id)
  description         = "CPU, memory, disk, and Azure SQL database performance for the spoke workloads."

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        name = "monitoring-overview"
        content = {
          json = "# Hub-Spoke VM Health\nThis workbook displays CPU, memory, and disk usage for the three spoke Linux VMs, plus basic performance metrics for the private Azure SQL database."
        }
      },
      {
        type = 3
        name = "vm-performance-chart"
        content = {
          version       = "KqlItem/1.0"
          query         = <<-KQL
            Perf
            | where TimeGenerated > ago(1h)
            | where CounterName in ("% Processor Time", "% Used Memory", "% Used Space")
            | summarize AverageValue = avg(CounterValue) by Computer, CounterName, bin(TimeGenerated, 5m)
            | render timechart
          KQL
          size          = 0
          title         = "VM CPU, memory, and disk usage - last hour"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "timechart"
        }
      },
      {
        type = 3
        name = "latest-vm-performance"
        content = {
          version       = "KqlItem/1.0"
          query         = <<-KQL
            Perf
            | where TimeGenerated > ago(15m)
            | where CounterName in ("% Processor Time", "% Used Memory", "% Used Space")
            | summarize arg_max(TimeGenerated, CounterValue) by Computer, CounterName
            | project Computer, CounterName, Value = round(CounterValue, 2), TimeGenerated
            | order by Computer asc, CounterName asc
          KQL
          size          = 1
          title         = "Latest VM measurements"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "table"
        }
      },
      {
        type = 1
        name = "sql-overview"
        content = {
          json = "## Azure SQL Database\nBasic SQL metrics are streamed to this workspace by the SQL database diagnostic setting."
        }
      },
      {
        type = 3
        name = "sql-performance-chart"
        content = {
          version       = "KqlItem/1.0"
          query         = <<-KQL
            AzureMetrics
            | where TimeGenerated > ago(1h)
            | where _ResourceId =~ "${azapi_resource.sql_database.id}"
            | where MetricName in ("cpu_percent", "physical_data_read_percent", "log_write_percent", "sessions_percent", "workers_percent", "storage_percent")
            | summarize AverageValue = avg(Average) by MetricName, bin(TimeGenerated, 5m)
            | render timechart
          KQL
          size          = 0
          title         = "SQL CPU, I/O, sessions, workers, and storage - last hour"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "timechart"
        }
      },
      {
        type = 3
        name = "latest-sql-performance"
        content = {
          version       = "KqlItem/1.0"
          query         = <<-KQL
            AzureMetrics
            | where TimeGenerated > ago(15m)
            | where _ResourceId =~ "${azapi_resource.sql_database.id}"
            | where MetricName in ("cpu_percent", "physical_data_read_percent", "log_write_percent", "sessions_percent", "workers_percent", "storage_percent")
            | summarize arg_max(TimeGenerated, Average) by MetricName
            | project MetricName, Value = round(Average, 2), TimeGenerated
            | order by MetricName asc
          KQL
          size          = 1
          title         = "Latest SQL database measurements"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "table"
        }
      }
    ]
    isLocked            = false
    fallbackResourceIds = [lower(azurerm_log_analytics_workspace.vm_monitoring.id), lower(azapi_resource.sql_database.id)]
  })
}
