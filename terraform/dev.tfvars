# =============================================================================
# Development Environment Variables
# =============================================================================

project_prefix             = "devdata"
resource_group_location    = "eastus"
resource_group_name_prefix = "synapse"
synapse_sql_admin_user     = "sqladmin"
# synapse_sql_admin_password = stored in Azure DevOps variable group (secret)

tags = {
  Environment = "dev"
  Project     = "SynapseDataPlatform"
  ManagedBy   = "Terraform"
  CostCenter  = "DataEngineering"
}
