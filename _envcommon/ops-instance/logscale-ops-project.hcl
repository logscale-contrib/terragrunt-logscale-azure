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
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract out common variables for reuse
  env = local.environment_vars.locals.environment

  # Expose the base source URL so different versions of the module can be deployed in different environments. This will
  # be used to construct the terraform block in the child terragrunt configurations.
  module_vars   = read_terragrunt_config(find_in_parent_folders("modules.hcl"))
  source_module = local.module_vars.locals.argocd_project

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
dependency "k8s_ops" {
  config_path = "${get_terragrunt_dir()}/../k8s-ops/"
}
dependency "ns" {
  config_path  = "${get_terragrunt_dir()}/../logscale-ops-ns/"
  skip_outputs = true
}
dependency "argo" {
  config_path  = "${get_terragrunt_dir()}/../common/k8s-argocd/"
  skip_outputs = true
}

generate "provider" {
  path      = "provider_k8s.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF

# provider "kubectl" {

#   apply_retry_count = 10
#   host              = "${dependency.k8s_ops.outputs.admin_host}"
#   client_certificate     = base64decode("${dependency.k8s_ops.outputs.admin_client_certificate}")
#   client_key             = base64decode("${dependency.k8s_ops.outputs.admin_client_key}")
#   cluster_ca_certificate = base64decode("${dependency.k8s_ops.outputs.admin_cluster_ca_certificate}")

#   load_config_file = false
# }

provider "kubernetes" {
  host              = "${dependency.k8s_ops.outputs.admin_host}"
  client_certificate     = base64decode("${dependency.k8s_ops.outputs.admin_client_certificate}")
  client_key             = base64decode("${dependency.k8s_ops.outputs.admin_client_key}")
  cluster_ca_certificate = base64decode("${dependency.k8s_ops.outputs.admin_cluster_ca_certificate}")
}

# provider "helm" {
#   kubernetes {
#   host              = "${dependency.k8s_ops.outputs.admin_host}"
#   client_certificate     = base64decode("${dependency.k8s_ops.outputs.admin_client_certificate}")
#   client_key             = base64decode("${dependency.k8s_ops.outputs.admin_client_key}")
#   cluster_ca_certificate = base64decode("${dependency.k8s_ops.outputs.admin_cluster_ca_certificate}")
#   }
# }
EOF
}
# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the parameters that are common across all
# environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name        = "logscale-ops"
  namespace   = "argocd"
  description = "Used for cluster wide resources"
  repository  = "https://argoproj.github.io/argo-helm"

  destinations = [
    {
      server    = "https://kubernetes.default.svc"
      name      = "in-cluster"
      namespace = "logscale-ops"
    },
    {
      server    = "https://kubernetes.default.svc"
      name      = "in-cluster"
      namespace = "monitoring"
    }
  ]
  namespaceResourceWhitelist = [
    {
      "group" : "*"
      "kind" : "*"
    }
  ]
  cluster_resource_whitelist = [
    {
      "group" : "rbac.authorization.k8s.io"
      "kind" : "ClusterRole"
    },
    {
      "group" : "rbac.authorization.k8s.io"
      "kind" : "ClusterRoleBinding"
    }
  ]
  "sourceRepos" = [
    "*",
  ]
}