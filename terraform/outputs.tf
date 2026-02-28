# =============================================================================
# Terraform Outputs for Azure Container Apps Deployment
# =============================================================================
# These outputs provide essential information after deployment:
# - Application URL for accessing the deployed service
# - Resource identifiers for CI/CD integration
# - Connection strings for monitoring and debugging
#
# Usage:
# - View outputs: terraform output
# - Get specific value: terraform output -raw app_url
# - JSON format: terraform output -json
# =============================================================================

# -----------------------------------------------------------------------------
# Application Outputs
# -----------------------------------------------------------------------------

output "app_url" {
  description = "The HTTPS URL of the deployed Container App"
  value       = "https://${azurerm_container_app.server.ingress[0].fqdn}"
}

output "app_fqdn" {
  description = "The fully qualified domain name of the Container App"
  value       = azurerm_container_app.server.ingress[0].fqdn
}

output "app_name" {
  description = "The name of the Container App (for CI/CD reference)"
  value       = azurerm_container_app.server.name
}

output "app_revision" {
  description = "The latest revision name of the Container App"
  value       = azurerm_container_app.server.latest_revision_name
}

# -----------------------------------------------------------------------------
# Resource Group Outputs
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "The name of the resource group containing all resources"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

# -----------------------------------------------------------------------------
# Container Registry Outputs
# -----------------------------------------------------------------------------

output "acr_login_server" {
  description = "The login server URL for Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_id" {
  description = "The resource ID of the Azure Container Registry"
  value       = azurerm_container_registry.main.id
}

# -----------------------------------------------------------------------------
# Container Apps Environment Outputs
# -----------------------------------------------------------------------------

output "container_app_environment_name" {
  description = "The name of the Container Apps Environment"
  value       = azurerm_container_app_environment.main.name
}

output "container_app_environment_id" {
  description = "The ID of the Container Apps Environment"
  value       = azurerm_container_app_environment.main.id
}

# -----------------------------------------------------------------------------
# Key Vault Outputs
# -----------------------------------------------------------------------------

output "key_vault_name" {
  description = "The name of the Key Vault for secrets management"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# -----------------------------------------------------------------------------
# Managed Identity Outputs
# -----------------------------------------------------------------------------

output "managed_identity_client_id" {
  description = "The client ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.container_app.client_id
}

output "managed_identity_principal_id" {
  description = "The principal ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.container_app.principal_id
}

# -----------------------------------------------------------------------------
# Monitoring Outputs
# -----------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "The workspace ID for Log Analytics queries"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights SDK"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights (legacy)"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

# -----------------------------------------------------------------------------
# CI/CD Integration Outputs
# -----------------------------------------------------------------------------
# These outputs are specifically formatted for use in GitHub Actions

output "github_actions_variables" {
  description = "Variables to set in GitHub Actions secrets"
  value = {
    AZURE_RESOURCE_GROUP     = azurerm_resource_group.main.name
    AZURE_ACR_NAME           = azurerm_container_registry.main.name
    AZURE_ACR_LOGIN_SERVER   = azurerm_container_registry.main.login_server
    AZURE_CONTAINER_APP_NAME = azurerm_container_app.server.name
    AZURE_CONTAINER_APP_ENV  = azurerm_container_app_environment.main.name
  }
}

# -----------------------------------------------------------------------------
# Cost Estimation Output
# -----------------------------------------------------------------------------

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    container_apps     = "~$35 (with scale-to-zero, actual cost depends on usage)"
    container_registry = "$5 (Basic tier)"
    key_vault          = "$0 (free tier - 10K operations/month)"
    log_analytics      = "$0 (free tier - 5GB/month)"
    networking         = "~$5 (egress traffic)"
    total_estimate     = "~$45/month (well under $90 budget)"
  }
}

# -----------------------------------------------------------------------------
# Deployment Summary
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of the deployed infrastructure"
  value = <<-EOT
    ╔══════════════════════════════════════════════════════════════════╗
    ║           Open Claude Cowork - Deployment Summary                ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ Application URL: https://${azurerm_container_app.server.ingress[0].fqdn}
    ║ Region: ${azurerm_resource_group.main.location}
    ║ Resource Group: ${azurerm_resource_group.main.name}
    ║ Container Registry: ${azurerm_container_registry.main.login_server}
    ║ Key Vault: ${azurerm_key_vault.main.name}
    ║ 
    ║ Scaling: ${var.min_replicas} - ${var.max_replicas} replicas
    ║ Resources: ${var.container_cpu} vCPU, ${var.container_memory}MB RAM
    ║ 
    ║ Next Steps:
    ║ 1. Push Docker image to ACR
    ║ 2. Configure GitHub Actions secrets
    ║ 3. Trigger deployment pipeline
    ╚══════════════════════════════════════════════════════════════════╝
  EOT
}
