# =============================================================================
# Synapse + Data Lake Variables
# =============================================================================

variable "project_prefix" {
  type        = string
  default     = "dataeng"
  description = "Prefix for all resource names"
}

variable "synapse_sql_admin_user" {
  type        = string
  default     = "sqladminuser"
  description = "SQL Administrator username for Synapse"
}

variable "synapse_sql_admin_password" {
  type        = string
  sensitive   = true
  description = "SQL Administrator password for Synapse (use Key Vault in production)"
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Project     = "DataEngineering"
    ManagedBy   = "Terraform"
  }
}
