#This file contains all external modules and versions

locals {
  rg = {
    base_url = "git::git@github.com:logscale-contrib/teraform-self-managed-logscale-azure-resource-group.git"
    version  = "?ref=v1.0.4"
  }
  net = {
    base_url = "git::git@github.com:logscale-contrib/teraform-self-managed-logscale-azure-network.git"
    version  = "?ref=v1.1.1"
  }
  vault = {
    base_url = "git::git@github.com:logscale-contrib/teraform-self-managed-logscale-azure-vault.git"
    version  = "?ref=v1.0.0"
  }
  k8s = {
    base_url = "git::git@github.com:logscale-contrib/teraform-self-managed-logscale-azure-aks.git"
    version  = "?ref=v1.7.3"
  }
  az_sp = {
    base_url = "git::git@github.com:logscale-contrib/teraform-self-managed-logscale-azure-serviceprincipal.git"
    version  = "?ref=v1.1.1"
  }
  az_store = {
    base_url = "tfr:///kumarvna/storage/azurerm"
    version  = "?version=2.5.0"
  }

  # vpc = {
  #   base_url = "tfr:///terraform-aws-modules/vpc/aws"
  #   version  = "?version=3.16.0"
  # }
  # aws_acm = {
  #   base_url = "tfr:///terraform-aws-modules/acm/aws"
  #   version  = "?version=4.1.0"
  # }
  # eks = {
  #   base_url = "git::git@github.com:logscale-contrib/tf-self-managed-logscale-aws-k8s-cluster.git"
  #   version  = "?ref=v3.4.23"
  # }
  # eks_addons = {
  #   base_url = "git::git@github.com:logscale-contrib/terraform-self-managed-logscale-aws-k8s-cluster-addons.git"
  #   version  = "?ref=v1.4.2"
  # }

  # aws_k8s_helm_w_iam = {
  #   base_url = "git::git@github.com:logscale-contrib/tf-self-managed-logscale-aws-k8s-helm-with-iam.git"
  #   version  = "?ref=v2.1.9"
  # }
  # eks_olm = {
  #   base_url = "git::git@github.com:logscale-contrib/terraform-k8s-olm.git"
  #   version  = "?ref=v1.0.0"
  # }
  # eks_linkerd_ta = {
  #   base_url = "git::git@github.com:logscale-contrib/terraform-k8s-linkerd-trust-anchor.git"
  #   version  = "?ref=v2.1.7"
  # }

  k8s_ns = {
    base_url = "git::git@github.com:logscale-contrib/terraform-k8s-namespace.git"
    version  = "?ref=v1.0.0"
  }

  k8s_helm = {
    base_url = "git::git@github.com:logscale-contrib/tf-self-managed-logscale-k8s-helm.git"
    version  = "?ref=v1.4.0"
  }
  helm_release = {
    base_url = "tfr:///terraform-module/release/helm"
    version  = "?version=2.8.0"
  }
  argocd_project = {
    #base_url = "tfr:///project-octal/k8s-argocd-project/kubernetes"
    #version  = "?version=2.0.0"
    base_url = "git::git@github.com:logscale-contrib/terraform-kubernetes-argocd-project.git"
    version  = ""

  }

  # aws_k8s_logscale_bucket_with_iam = {
  #   base_url = "git::git@github.com:logscale-contrib/terraform-aws-logscale-bucket-with-iam.git"
  #   version  = "?ref=v1.3.0"
  # }
}