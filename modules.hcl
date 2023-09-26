#This file contains all external modules and versions

locals {

  argocd_project = {
    #base_url = "tfr:///project-octal/k8s-argocd-project/kubernetes"
    #version  = "?version=2.0.0"
    source = "github.com/logscale-contrib/terraform-kubernetes-argocd-project.git"
    version  = ""

  }

  # aws_k8s_logscale_bucket_with_iam = {
  #   base_url = "github.com/logscale-contrib/terraform-aws-logscale-bucket-with-iam.git"
  #   version  = "?ref=v1.3.0"
  # }
}