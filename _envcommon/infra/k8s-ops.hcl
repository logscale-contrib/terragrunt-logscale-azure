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
  source = "tfr:///segateway/akscluster/azurerm?version=2.2.9"
}


# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {

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


# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the parameters that are common across all
# environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  resource_group = dependency.rg_ops.outputs.resource_group_name
  cluster_name = dependency.rg_ops.outputs.resource_group_name
  location       = dependency.rg_ops.outputs.resource_group_location
  subnet_id      = dependency.net_ops.outputs.virtual_subnet_id

  subnet_id_ag           = dependency.net_ops.outputs.virtual_subnet_id_ag
  prefix                 = "logscale-ops-${local.env}"
  agent_size             = "Standard_B2s"
  agent_max              = 6
  agent_compute_size     = "Standard_D4as_v5"
  agent_compute_min      = 0
  agent_compute_max      = 9
  agent_nvme_size        = "Standard_L8s_v3"
  #"Standard_L16s_v3"
  #"Standard_L8s_v3"
  #"Standard_L8as_v3"
  agent_nvme_min = 0
  agent_nvme_max = 4
  tags           = local.tags
}