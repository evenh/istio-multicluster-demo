output "kubeconfig" {
  sensitive = true
  value = {
    host                   = digitalocean_kubernetes_cluster.this.endpoint
    client_certificate     = digitalocean_kubernetes_cluster.this.kube_config.0.client_certificate
    client_key             = digitalocean_kubernetes_cluster.this.kube_config.0.client_key
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
    token                  = digitalocean_kubernetes_cluster.this.kube_config.0.token
  }
}

output "name" {
  value = var.name
}
