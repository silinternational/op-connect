
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  default_tags {
    tags = {
      managed_by        = "terraform"
      workspace         = terraform.workspace
      itse_app_customer = var.customer
      itse_app_env      = data.terraform_remote_state.common.outputs.app_environment
      itse_app_name     = var.app_name
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}
