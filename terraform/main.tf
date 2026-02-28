# =============================================================================
# Terraform Configuration for Azure Container Apps Deployment
# =============================================================================
# This configuration deploys the Open Claude Cowork server to Azure Container Apps
# in the West Europe region as specified by the user.
#
# Architecture:
# - Azure Container Apps Environment (serverless container hosting)
# - Azure Container Registry (private image storage)
# - Azure Key Vault (secrets management for API keys)
# - Azure Log Analytics (monitoring and logging)
# - Managed Identity (secure authentication without credentials)
#
# Cost Optimization:
# - Scale-to-zero enabled (pay only when processing requests)
# - Consumption plan (no reserved capacity charges)
# - Basic tier Container Registry ($5/month)
# - Free tier Key Vault and Log Analytics
#
# Estimated Monthly Cost: ~$45 (well under $90 budget)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }

  # Backend configuration for state storage
  # Uncomment and configure for production use
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstateaccount"
  #   container_name       = "tfstate"
  #   key                  = "open-claude-cowork.tfstate"
  # }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "azurerm" {
  features {
    # Soft delete protection for Key Vault
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    # Prevent accidental resource group deletion
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
# Get current Azure client configuration for Key Vault access policies
data "azurerm_client_config" "current" {}

# Get current Azure AD user/service principal for Key Vault admin access
data "azuread_client_config" "current" {}

# -----------------------------------------------------------------------------
# Random String for Unique Naming
# -----------------------------------------------------------------------------
# Azure resources require globally unique names
# This suffix ensures uniqueness across deployments
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------
locals {
  # Naming convention: {project}-{environment}-{resource}-{suffix}
  name_prefix = "${var.project_name}-${var.environment}"
  name_suffix = random_string.suffix.result

  # Common tags applied to all resources for cost tracking and management
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "SmitVgithub/open-claude-cowork"
    CostCenter  = "claude-cowork"
    CreatedAt   = timestamp()
  }

  # Container Apps configuration
  container_app_name = "claude-cowork-server"
  container_port     = 3000
}

# =============================================================================
# Resource Group
# =============================================================================
# Logical container for all Azure resources
# Enables easy cleanup and cost tracking
resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg-${local.name_suffix}"
  location = var.azure_region
  tags     = local.common_tags
}

# =============================================================================
# Log Analytics Workspace
# =============================================================================
# Centralized logging for Container Apps, Key Vault, and other resources
# Required by Azure Container Apps Environment
# Free tier: 5GB/month ingestion, 31 days retention
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-logs-${local.name_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018" # Pay-as-you-go, first 5GB free
  retention_in_days   = 30          # Minimum retention for cost optimization

  # Enable features for container monitoring
  daily_quota_gb = 1 # Limit daily ingestion to control costs

  tags = local.common_tags
}

# =============================================================================
# Application Insights
# =============================================================================
# APM for the Express.js server
# Provides request tracing, error tracking, and performance metrics
resource "azurerm_application_insights" "main" {
  name                = "${local.name_prefix}-insights-${local.name_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "Node.JS"

  # Sampling reduces costs for high-traffic applications
  sampling_percentage = 100 # Full sampling for low-traffic app

  tags = local.common_tags
}

# =============================================================================
# Azure Container Registry
# =============================================================================
# Private registry for Docker images
# Basic tier: $5/month, 10GB storage, sufficient for this project
resource "azurerm_container_registry" "main" {
  name                = "${replace(local.name_prefix, "-", "")}acr${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic" # $5/month, sufficient for small projects
  admin_enabled       = false   # Disabled for security - use managed identity

  # Enable content trust for image signing (optional, requires Premium SKU)
  # trust_policy {
  #   enabled = true
  # }

  tags = local.common_tags
}

# =============================================================================
# User-Assigned Managed Identity
# =============================================================================
# Enables Container Apps to pull images from ACR and access Key Vault
# without storing credentials in environment variables
resource "azurerm_user_assigned_identity" "container_app" {
  name                = "${local.name_prefix}-identity-${local.name_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Grant ACR pull permission to the managed identity
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

# =============================================================================
# Azure Key Vault
# =============================================================================
# Secure storage for sensitive configuration:
# - ANTHROPIC_API_KEY
# - COMPOSIO_API_KEY
# - Other secrets
#
# Free tier: 10,000 operations/month
resource "azurerm_key_vault" "main" {
  name                = "${replace(local.name_prefix, "-", "")}kv${local.name_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard" # Free tier sufficient

  # Security settings
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  enable_rbac_authorization       = true # Use RBAC instead of access policies
  purge_protection_enabled        = true # Prevent accidental deletion
  soft_delete_retention_days      = 7    # Minimum for cost optimization

  # Network security - restrict access
  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow" # Change to "Deny" and add IP rules for production
  }

  tags = local.common_tags
}

# Grant Key Vault Secrets User role to the managed identity
# This allows Container Apps to read secrets
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

# Grant Key Vault Administrator role to the current user/service principal
# This allows Terraform and CI/CD to manage secrets
resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# =============================================================================
# Key Vault Secrets
# =============================================================================
# Store sensitive configuration in Key Vault
# Values should be provided via Terraform variables or CI/CD secrets

# Anthropic API Key - Required for Claude Agent SDK
resource "azurerm_key_vault_secret" "anthropic_api_key" {
  name         = "anthropic-api-key"
  value        = var.anthropic_api_key
  key_vault_id = azurerm_key_vault.main.id

  # Ensure role assignment is created first
  depends_on = [azurerm_role_assignment.keyvault_admin]

  tags = local.common_tags
}

# Composio API Key - Optional for Tool Router
resource "azurerm_key_vault_secret" "composio_api_key" {
  count        = var.composio_api_key != "" ? 1 : 0
  name         = "composio-api-key"
  value        = var.composio_api_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.keyvault_admin]

  tags = local.common_tags
}

# =============================================================================
# Container Apps Environment
# =============================================================================
# Shared environment for Container Apps
# Provides:
# - Virtual network integration
# - Log Analytics integration
# - Internal load balancing
# - HTTPS ingress with managed certificates
resource "azurerm_container_app_environment" "main" {
  name                       = "${local.name_prefix}-env-${local.name_suffix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Workload profile for consumption-based pricing
  # This enables scale-to-zero capability
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = local.common_tags
}

# =============================================================================
# Container App
# =============================================================================
# The main application deployment
# Configured for:
# - Scale-to-zero (cost optimization)
# - Automatic HTTPS with managed certificate
# - Key Vault secret references
# - Health probes for reliability
resource "azurerm_container_app" "server" {
  name                         = local.container_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single" # Single active revision for simplicity

  # Managed identity for ACR pull and Key Vault access
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  # Container registry configuration
  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  # Ingress configuration - external HTTPS access
  ingress {
    external_enabled = true
    target_port      = local.container_port
    transport        = "http" # Container Apps handles HTTPS termination

    # Traffic distribution (100% to latest revision)
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Secret references from Key Vault
  secret {
    name                = "anthropic-api-key"
    key_vault_secret_id = azurerm_key_vault_secret.anthropic_api_key.id
    identity            = azurerm_user_assigned_identity.container_app.id
  }

  # Container template
  template {
    # Container specification
    container {
      name   = "server"
      image  = "${azurerm_container_registry.main.login_server}/${local.container_app_name}:${var.image_tag}"
      cpu    = var.container_cpu
      memory = "${var.container_memory / 1024}Gi" # Convert MB to Gi

      # Environment variables
      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = tostring(local.container_port)
      }

      # Secret reference for Anthropic API Key
      env {
        name        = "ANTHROPIC_API_KEY"
        secret_name = "anthropic-api-key"
      }

      # Application Insights connection string for monitoring
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.main.connection_string
      }

      # Liveness probe - checks if container is running
      liveness_probe {
        transport        = "HTTP"
        path             = "/health"
        port             = local.container_port
        initial_delay    = 10
        interval_seconds = 30
        timeout          = 5
        failure_count_threshold = 3
      }

      # Readiness probe - checks if container can accept traffic
      readiness_probe {
        transport        = "HTTP"
        path             = "/health"
        port             = local.container_port
        interval_seconds = 10
        timeout          = 5
        failure_count_threshold = 3
      }

      # Startup probe - allows longer startup time
      startup_probe {
        transport        = "HTTP"
        path             = "/health"
        port             = local.container_port
        interval_seconds = 5
        timeout          = 3
        failure_count_threshold = 10
      }
    }

    # Scaling configuration - scale-to-zero enabled
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    # HTTP scaling rule - scale based on concurrent requests
    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = 10 # Scale up when >10 concurrent requests per replica
    }
  }

  tags = local.common_tags

  # Ensure dependencies are created first
  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.keyvault_secrets_user,
  ]
}

# =============================================================================
# Monitoring Alerts
# =============================================================================
# Alert rules for operational awareness

# Action group for alert notifications
resource "azurerm_monitor_action_group" "main" {
  name                = "${local.name_prefix}-alerts-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "claudealert"

  # Email notification (configure with actual email)
  dynamic "email_receiver" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      name          = "admin"
      email_address = var.alert_email
    }
  }

  tags = local.common_tags
}

# Alert: High error rate
resource "azurerm_monitor_metric_alert" "high_error_rate" {
  name                = "${local.name_prefix}-high-errors"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when error rate exceeds threshold"
  severity            = 2 # Warning
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Alert: Container restarts
resource "azurerm_monitor_metric_alert" "container_restarts" {
  name                = "${local.name_prefix}-restarts"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app_environment.main.id]
  description         = "Alert when container restarts frequently"
  severity            = 1 # Error
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.app/managedenvironments"
    metric_name      = "RestartCount"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}
