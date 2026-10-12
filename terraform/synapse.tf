# =============================================================================
# Azure Synapse Analytics + Data Lake Gen2 Infrastructure
# =============================================================================

# -----------------------------------------------------------------------------
# Data Lake Storage Gen2 (with hierarchical namespace)
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "datalake" {
  name                     = "${var.project_prefix}datalake"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # Hierarchical namespace = Data Lake Gen2

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Data Lake Containers (Bronze, Silver, Gold - Medallion Architecture)
# -----------------------------------------------------------------------------
resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name               = "silver"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name               = "gold"
  storage_account_id = azurerm_storage_account.datalake.id
}

# -----------------------------------------------------------------------------
# Azure Synapse Workspace
# -----------------------------------------------------------------------------
resource "azurerm_synapse_workspace" "synapse" {
  name                                 = "${var.project_prefix}-synapse-ws"
  resource_group_name                  = azurerm_resource_group.rg.name
  location                             = azurerm_resource_group.rg.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.bronze.id
  sql_administrator_login              = var.synapse_sql_admin_user
  sql_administrator_login_password     = var.synapse_sql_admin_password

  # Managed Identity for accessing storage
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Synapse Firewall Rule - Allow Azure Services
# -----------------------------------------------------------------------------
resource "azurerm_synapse_firewall_rule" "allow_azure" {
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

# -----------------------------------------------------------------------------
# Synapse Dedicated SQL Pool (for data warehousing)
# -----------------------------------------------------------------------------
resource "azurerm_synapse_sql_pool" "dedicated" {
  name                 = "${var.project_prefix}sqlpool"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  sku_name             = "DW100c"  # Smallest SKU for dev/test
  create_mode          = "Default"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Synapse Spark Pool (for PySpark transformations)
# -----------------------------------------------------------------------------
resource "azurerm_synapse_spark_pool" "spark" {
  name                 = "${var.project_prefix}spark"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  node_size_family     = "MemoryOptimized"
  node_size            = "Small"
  node_count           = 3

  auto_pause {
    delay_in_minutes = 15  # Auto-pause after 15 min idle
  }

  auto_scale {
    min_node_count = 3
    max_node_count = 10
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Key Vault for storing secrets
# -----------------------------------------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                = "${var.project_prefix}-kv"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Allow Synapse Managed Identity to access secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_synapse_workspace.synapse.identity[0].principal_id

    secret_permissions = [
      "Get",
      "List",
    ]
  }

  tags = var.tags
}

# Get current Azure config (for tenant_id)
data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# RBAC: Grant Synapse access to Data Lake
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "synapse_storage_contributor" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse.identity[0].principal_id
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "synapse_workspace_name" {
  value = azurerm_synapse_workspace.synapse.name
}

output "synapse_sql_endpoint" {
  value = azurerm_synapse_workspace.synapse.connectivity_endpoints["sql"]
}

output "synapse_serverless_endpoint" {
  value = azurerm_synapse_workspace.synapse.connectivity_endpoints["sqlOnDemand"]
}

output "datalake_endpoint" {
  value = azurerm_storage_account.datalake.primary_dfs_endpoint
}

output "synapse_studio_url" {
  value = "https://web.azuresynapse.net?workspace=%2fsubscriptions%2f${data.azurerm_client_config.current.subscription_id}%2fresourceGroups%2f${azurerm_resource_group.rg.name}%2fproviders%2fMicrosoft.Synapse%2fworkspaces%2f${azurerm_synapse_workspace.synapse.name}"
}
