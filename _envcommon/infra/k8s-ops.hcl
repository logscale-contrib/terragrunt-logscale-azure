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
  source_module = local.module_vars.locals.k8s

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
  config_path = "${get_terragrunt_dir()}/../infra/resourcegroup-ops/"
}
dependency "net_ops" {
  config_path = "${get_terragrunt_dir()}/../infra/network-ops/"
}
dependency "vault_ops" {
  config_path = "${get_terragrunt_dir()}/../infra/vault-ops/"
}


# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the parameters that are common across all
# environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  resource_group = dependency.rg_ops.outputs.resource_group_name
  location       = dependency.rg_ops.outputs.resource_group_location
  subnet_id      = dependency.net_ops.outputs.virtual_subnet_id

  subnet_id_ag            = dependency.net_ops.outputs.virtual_subnet_id_ag
  prefix                  = "logscale-ops-${local.env}"
  disk_encryption_set_id  = dependency.vault_ops.outputs.disk_encryption_set_id
  agent_size              = "standard_d2s_v5"
  agent_size_max          = 6
  agent_size_logscale     = "Standard_L8as_v3"
  agent_size_logscale_max = 6
  tags                    = local.tags
}