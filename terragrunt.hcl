# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Terragrunt is a thin wrapper for Terraform that provides extra tools for working with multiple Terraform modules,
# remote state, and locking: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------


# Generate an AWS provider block
generate "provider" {
  path      = "provider.g.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"
}
provider "github" {
  owner = "tdc-pozo-2021"
  token = "${get_env("GITHUB_TOKEN")}"
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an aws s3 bucket
remote_state {
  backend = "s3"
  config = {
    bucket               = get_env("TF_STATE_BUCKET")
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    region               = "us-east-1"
  }
  generate = {
    path      = "backend.g.tf"
    if_exists = "overwrite_terragrunt"
  }
}