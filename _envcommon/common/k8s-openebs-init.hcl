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
  source_module = local.module_vars.locals.helm_release

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
dependency "k8s_ops" {
  config_path = "${get_terragrunt_dir()}/../../k8s-ops/"
}
dependency "openebs" {
  config_path  = "${get_terragrunt_dir()}/../k8s-openebs/"
  skip_outputs = true
}

generate "provider" {
  path      = "provider_k8s.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF

provider "helm" {
  kubernetes {
  host              = "${dependency.k8s_ops.outputs.admin_host}"
  client_certificate     = base64decode("${dependency.k8s_ops.outputs.admin_client_certificate}")
  client_key             = base64decode("${dependency.k8s_ops.outputs.admin_client_key}")
  cluster_ca_certificate = base64decode("${dependency.k8s_ops.outputs.admin_cluster_ca_certificate}")
  }
}
EOF
}
# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the parameters that are common across all
# environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {


  repository = "https://logscale-contrib.github.io/openebs-withlvm-init"
  namespace  = "kube-system"

  app = {
    chart            = "openebs-withlvm-init"
    name             = "vi"
    version          = "2.2.4"
    create_namespace = false
    deploy           = 1
    wait             = false
  }

  values = [<<YAML
# Default values for openebs-withlvm-init.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.
config:
  platform: azure
allowedTopologies:
  key: kubernetes.azure.com/agentpool
  values: ["nvme"]  
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.azure.com/agentpool
              operator: In
              values: ["nvme"]
            - key: kubernetes.azure.com/cluster                
              operator: Exists              
            - key: type
              operator: NotIn
              values:
              - virtual-kubelet              
            - key: kubernetes.io/os
              operator: In
              values:
                - linux
tolerations:
  - key: workloadClass
    operator: Equal
    value: nvme
    effect: NoSchedule            
  - key: CriticalAddonsOnly        
    operator: Exists      
  - effect: NoExecute        
    operator: Exists      
  - effect: NoSchedule        
    operator: Exists    
YAML
  ]
}
