# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for mysql. The common variables for each environment to
# deploy mysql are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If any environment
# needs to deploy a different module version, it should redefine this block with a different ref to override the
# deployed version.

terraform {
  source = "${local.source_module.base_url}${local.source_module.version}"
}


# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Automatically load modules variables
  module_vars   = read_terragrunt_config(find_in_parent_folders("modules.hcl"))
  source_module = local.module_vars.locals.az_store

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract out common variables for reuse
  env          = local.environment_vars.locals.environment
  location_ops = local.environment_vars.locals.location_ops

  tag_vars = read_terragrunt_config(find_in_parent_folders("tags.hcl"))
  tags = merge(
    local.tag_vars.locals.tags,
    {
      Environment   = local.env
      GitRepository = run_cmd("sh", "-c", "git config --get remote.origin.url")
      Role          = "ops"
    },
  )
}

dependency "rg_ops" {
  config_path = "${get_terragrunt_dir()}/../../infra/resourcegroup-ops/"
}



# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the parameters that are common across all
# environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  resource_group_name = dependency.rg_ops.outputs.resource_group_name
  location       = dependency.rg_ops.outputs.resource_group_location
  
  storage_account_name = "logscale-ops-${local.env}"

  containers_list = [
    { name = "data", access_type = "container" },
    { name = "archive", access_type = "container" },
    { name = "export", access_type = "container" }
  ]

  enable_versioning = true
  skuname           = "Standard_RAGRS"

#   lifecycles = [
#     {
#       prefix_match               = ["data/"]
#       tier_to_cool_after_days    = 90
#       tier_to_archive_after_days = 120
#       delete_after_days          = 365
#       snapshot_delete_after_days = 30
#     },
#     {
#       prefix_match               = ["archive/"]
#       tier_to_cool_after_days    = 3
#       tier_to_archive_after_days = 7
#       delete_after_days          = 60
#       snapshot_delete_after_days = 30
#     },
#     {
#       prefix_match               = ["export/"]
#       tier_to_cool_after_days    = 3
#       tier_to_archive_after_days = 7
#       delete_after_days          = 60
#       snapshot_delete_after_days = 30
#     }
#   ]

  tags = local.tags
}