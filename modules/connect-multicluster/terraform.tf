terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  alias                  = "east"
  host                   = var.east_cluster.kubeconfig.host
  client_certificate     = var.east_cluster.kubeconfig.client_certificate
  client_key             = var.east_cluster.kubeconfig.client_key
  cluster_ca_certificate = var.east_cluster.kubeconfig.cluster_ca_certificate
  token                  = var.east_cluster.kubeconfig.token
}

provider "kubernetes" {
  alias                  = "west"
  host                   = var.west_cluster.kubeconfig.host
  client_certificate     = var.west_cluster.kubeconfig.client_certificate
  client_key             = var.west_cluster.kubeconfig.client_key
  cluster_ca_certificate = var.west_cluster.kubeconfig.cluster_ca_certificate
  token                  = var.west_cluster.kubeconfig.token
}
