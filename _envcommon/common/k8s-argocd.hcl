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
  source = "tfr:///terraform-module/release/helm?version=2.8.0"
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

  dns         = read_terragrunt_config(find_in_parent_folders("dns.hcl"))
  domain_name = local.dns.locals.domain_name

  host_name = "argocd"

}

dependency "rg_ops" {
  config_path = "${get_terragrunt_dir()}/../../infra/resourcegroup-ops/"
}
dependency "k8s_ops" {
  config_path = "${get_terragrunt_dir()}/../../k8s-ops/"
}
dependency "ns" {
  config_path  = "${get_terragrunt_dir()}/../k8s-ns-argocd/"
  skip_outputs = true
}
dependency "operator-monitoring" {
  config_path  = "${get_terragrunt_dir()}/../k8s-prom-crds/"
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
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"

  app = {
    name             = "cw"
    create_namespace = true

    chart   = "argo-cd"
    version = "5.17.4"

    wait   = true
    deploy = 1
  }
  values = [<<EOF
global:
  image:
    tag: v2.5.0-rc3
argo-cd:
  config:
    application.resourceTrackingMethod: annotation
redis-ha:
  enabled: true

controller:
  replicas: 2

repoServer:
  autoscaling:
    enabled: true
    minReplicas: 2

applicationSet:
  replicas: 2

server:
  autoscaling:
    enabled: true
    minReplicas: 2
  extraArgs:
  - --insecure
  service:
   type: ClusterIP
  ingress:
    enabled: true
    hosts:
      - ${local.host_name}.${local.domain_name}
    # ingressClassName: azure-application-gateway
    annotations:
      external-dns.alpha.kubernetes.io/hostname: ${local.host_name}.${local.domain_name}
      kubernetes.io/ingress.class: azure/application-gateway
      cert-manager.io/cluster-issuer: aag-letsencrypt
      appgw.ingress.kubernetes.io/ssl-redirect: true
    tls: 
      - secretName: argocd-ingress-tls
        hosts:
          - ${local.host_name}.${local.domain_name}

EOF 
  ]
}