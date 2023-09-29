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
  source = "github.com/logscale-contrib/tf-self-managed-logscale-k8s-helm.git?ref=v1.4.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract out common variables for reuse
  env = local.environment_vars.locals.environment


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

  humio                    = read_terragrunt_config(find_in_parent_folders("humio.hcl"))
  humio_rootUser           = local.humio.locals.humio_rootUser
  humio_license            = local.humio.locals.humio_license
  humio_sso_idpCertificate = local.humio.locals.humio_sso_idpCertificate
  humio_sso_signOnUrl      = local.humio.locals.humio_sso_signOnUrl
  humio_sso_entityID       = local.humio.locals.humio_sso_entityID

}

dependency "rg_ops" {
  config_path = "${get_terragrunt_dir()}/../../infra/resourcegroup-ops/"
}
dependency "k8s_ops" {
  config_path = "${get_terragrunt_dir()}/../../k8s-ops/"
}
dependency "ns" {
  config_path  = "${get_terragrunt_dir()}/../../logscale-ops-ns/"
  skip_outputs = true
}
dependency "argo" {
  config_path  = "${get_terragrunt_dir()}/../../common/k8s-argocd/"
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
  uniqueName = "logscale-${local.env}"

  repository = "ghcr.io/logscale-contrib/helm-logscale/charts"

  release          = "ops"
  chart            = "logscale"
  chart_version    = "5.0.0"
  namespace        = "logscale-ops"
  create_namespace = false
  project          = "logscale-ops"

  values = yamldecode(<<EOF
humio:
  # External URI
  fqdn: "logscale-ops.${local.domain_name}"
  fqdnInputs: "logscale-ops-inputs.${local.domain_name}"

  license: ${local.humio_license}
  
  # Signon
  rootUser: ${local.humio_rootUser}
  sso:
    signOnUrl: ${local.humio_sso_signOnUrl}
    entityID: ${local.humio_sso_entityID}
    idpCertificate: ${base64encode(local.humio_sso_idpCertificate)}

  # Object Storage Settings
  s3mode: s3proxy
  s3proxy: 
    secret: ops-s3proxy-secret
    endpoint: http://ops-s3proxy
  buckets:
    region: us-east-1
    storage: data

  #Kafka
  kafka:
    manager: strimzi
    prefixEnable: true
    strimziCluster: "ops-logscale-strimzi-kafka"
    externalKafkaHostname: "ops-logscale-strimzi-kafka-kafka-bootstrap:9092"
    # extraConfig: |
    #   sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="ops-kafka-user" password="XKZeXtSTGi2x";
    #   sasl.mechanism=SCRAM-SHA-512
    #   security.protocol=SASL_PLAINTEXT
    # # extraConfig: "security.protocol=tls"
    
    
  #Image is shared by all node pools
  image:
    tag: 1.70.0

  # Primary Node pool used for digest/storage
  nodeCount: 3
  #In general for these node requests and limits should match
  resources:
    requests:
      memory: 4Gi
      cpu: 4
    limits:
      memory: 4Gi
      cpu: 4

  podAnnotations:
    "config.linkerd.io/skip-outbound-ports": "443"
    "instrumentation.opentelemetry.io/inject-java": "true"
    "instrumentation.opentelemetry.io/container-names": "humio"
  serviceAccount:
    name: "logscale-ops"
  tolerations:
    - key: "workloadClass"
      operator: "Equal"
      value: "nvme"
      effect: "NoSchedule"
    - key: "node.kubernetes.io/disk-pressure"
      operator: "Exists"
      tolerationSeconds: 300
      effect: "NoExecute"      
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: "kubernetes.io/arch"
                operator: "In"
                values: ["amd64"]
              - key: "kubernetes.io/os"
                operator: "In"
                values: ["linux"]
              - key: "kubernetes.azure.com/agentpool"
                operator: "In"
                values: ["nvme"]
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/instance
                operator: In
                values: ["ops-logscale"]
              - key: humio.com/node-pool
                operator: In
                values: ["ops-logscale"]
          topologyKey: "kubernetes.io/hostname"
  dataVolumePersistentVolumeClaimSpecTemplate:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: "1Ti"
    storageClassName: "openebs-lvmpv"

  ingress:
    ui:
      enabled: true
      tls: true
      annotations:
        "external-dns.alpha.kubernetes.io/hostname": "logscale-ops.${local.domain_name}"
        "kubernetes.io/ingress.class": "azure/application-gateway"
        "cert-manager.io/cluster-issuer": "aag-letsencrypt"
        "appgw.ingress.kubernetes.io/ssl-redirect": "true"
          
    inputs:
      enabled: true
      tls: true    
      annotations:
        "external-dns.alpha.kubernetes.io/hostname": "logscale-ops-inputs.${local.domain_name}"
        "kubernetes.io/ingress.class": "azure/application-gateway"
        "cert-manager.io/cluster-issuer": "aag-letsencrypt"
        "appgw.ingress.kubernetes.io/ssl-redirect": "true"

  nodepools:
    ingest:
      nodeCount: 2
      resources:
        limits:
          cpu: "2"
          memory: 3Gi
        requests:
          cpu: "2"
          memory: 3Gi 
      tolerations:
          - key: "workloadClass"
            operator: "Equal"
            value: "nvme"
            effect: "NoSchedule"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: "kubernetes.io/arch"
                    operator: "In"
                    values: ["amd64"]
                  - key: "kubernetes.io/os"
                    operator: "In"
                    values: ["linux"]
                  - key: "kubernetes.azure.com/agentpool"
                    operator: "In"
                    values: ["compute"]
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app.kubernetes.io/instance
                    operator: In
                    values: ["ops-logscale"]
                  - key: humio.com/node-pool
                    operator: In
                    values: ["ops-logscale-ingest-only"]
              topologyKey: "kubernetes.io/hostname"          

    ui:
      nodeCount: 2
      resources:
        limits:
          cpu: "2"
          memory: 3Gi
        requests:
          cpu: "2"
          memory: 3Gi
      tolerations:
          - key: "workloadClass"
            operator: "Equal"
            value: "nvme"
            effect: "NoSchedule"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: "kubernetes.io/arch"
                    operator: "In"
                    values: ["amd64"]
                  - key: "kubernetes.io/os"
                    operator: "In"
                    values: ["linux"]
                  - key: "kubernetes.azure.com/agentpool"
                    operator: "In"
                    values: ["compute"]
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app.kubernetes.io/instance
                    operator: In
                    values: ["ops-logscale"]
                  - key: humio.com/node-pool
                    operator: In
                    values: ["ops-logscale-http-only"]
              topologyKey: "kubernetes.io/hostname"
EOF
  )

}
