# =============================================================================
# Terraform Variables for Azure Container Apps Deployment
# =============================================================================
# This file defines all configurable parameters for the infrastructure.
# Variables are organized by category for clarity.
#
# Usage:
# - Set values in terraform.tfvars (not committed to git)
# - Or pass via CLI: terraform apply -var="anthropic_api_key=sk-..."
# - Or set environment variables: TF_VAR_anthropic_api_key=sk-...
# =============================================================================

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
  default     = "claude-cowork"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

# -----------------------------------------------------------------------------
# Azure Configuration
# -----------------------------------------------------------------------------

variable "azure_region" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "westeurope" # User specified West Europe

  validation {
    condition = contains([
      "westeurope",
      "northeurope",
      "eastus",
      "eastus2",
      "westus",
      "westus2",
      "centralus"
    ], var.azure_region)
    error_message = "Azure region must be a valid region identifier."
  }
}

# -----------------------------------------------------------------------------
# Container Configuration
# -----------------------------------------------------------------------------

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "container_cpu" {
  description = "CPU allocation for the container (in cores)"
  type        = number
  default     = 1.0 # 1 vCPU as specified in infrastructure plan

  validation {
    condition     = var.container_cpu >= 0.25 && var.container_cpu <= 4
    error_message = "Container CPU must be between 0.25 and 4 cores."
  }
}

variable "container_memory" {
  description = "Memory allocation for the container (in MB)"
  type        = number
  default     = 2048 # 2GB as specified in infrastructure plan

  validation {
    condition     = var.container_memory >= 512 && var.container_memory <= 8192
    error_message = "Container memory must be between 512MB and 8192MB."
  }
}

# -----------------------------------------------------------------------------
# Scaling Configuration
# -----------------------------------------------------------------------------

variable "min_replicas" {
  description = "Minimum number of container replicas (0 enables scale-to-zero)"
  type        = number
  default     = 0 # Scale-to-zero for cost optimization

  validation {
    condition     = var.min_replicas >= 0 && var.min_replicas <= 10
    error_message = "Minimum replicas must be between 0 and 10."
  }
}

variable "max_replicas" {
  description = "Maximum number of container replicas"
  type        = number
  default     = 3 # As specified in infrastructure plan

  validation {
    condition     = var.max_replicas >= 1 && var.max_replicas <= 30
    error_message = "Maximum replicas must be between 1 and 30."
  }
}

# -----------------------------------------------------------------------------
# Secrets Configuration
# -----------------------------------------------------------------------------
# IMPORTANT: Never commit actual secret values to version control!
# Use terraform.tfvars (gitignored) or environment variables.

variable "anthropic_api_key" {
  description = "Anthropic API key for Claude Agent SDK (required)"
  type        = string
  sensitive   = true # Prevents value from appearing in logs

  validation {
    condition     = length(var.anthropic_api_key) > 0
    error_message = "Anthropic API key is required."
  }
}

variable "composio_api_key" {
  description = "Composio API key for Tool Router (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Monitoring Configuration
# -----------------------------------------------------------------------------

variable "alert_email" {
  description = "Email address for alert notifications (optional)"
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Alert email must be a valid email address or empty."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention must be between 30 and 730 days."
  }
}
