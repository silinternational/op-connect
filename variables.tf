
variable "tf_remote_common_organization" {
  description = "organization for common infrastructure configuration workspace"
  type        = string
}

variable "tf_remote_common_workspace" {
  description = "workspace for common infrastructure configuration"
  type        = string
}

variable "aws_region" {
  default = "us-east-1"
}

variable "app_name" {
  description = "short app name for use in configuration and infrastructure"
  default     = "op-connect"
}

variable "subdomain" {
  description = "subdomain (host name) of the app"
  default     = "connect"
}

variable "customer" {
  description = "Customer name, used in AWS tags"
  type        = string
}

variable "api_cpu" {
  description = "cpu size for connect-api container"
  default     = 32
}

variable "api_memory" {
  description = "memory size for connect-api container"
  default     = 32
}

variable "sync_cpu" {
  description = "cpu size for connect-sync container"
  default     = 32
}

variable "sync_memory" {
  description = "memory size for connect-sync container"
  default     = 32
}

variable "desired_count" {
  description = "number of tasks to run"
  default     = 1
}

/*
 * 1Password Connect configuration
 */

variable "onepassword_credentials" {
  description = "1Password credentials, base64url encoded"
  type        = string
  sensitive   = true
}

variable "log_level" {
  description = "log level for api and sync services"
  default     = "info"
}

variable "use_lets_encrypt" {
  description = "set to true to enable Let's Encrypt for connect-api"
  default     = false
}

/*
 * Provider configuration
 */

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_domain" {
  type = string
}

variable "cloudflare_token" {
  description = "Limited access token for DNS updates"
  type        = string
  sensitive   = true
}

