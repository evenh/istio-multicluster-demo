resource "digitalocean_vpc" "this" {
  name   = var.name
  region = var.region

  ip_range = "10.${var.vpc_id}.0.0/16"
}

resource "digitalocean_kubernetes_cluster" "this" {
  name                             = var.name
  region                           = var.region
  version                          = var.k8s_version
  auto_upgrade                     = false
  vpc_uuid                         = digitalocean_vpc.this.id
  destroy_all_associated_resources = true

  cluster_subnet = "10.${var.vpc_id + 5}.0.0/18"
  service_subnet = "10.${var.vpc_id + 5}.128.0/18"

  maintenance_policy {
    day        = "saturday"
    start_time = "00:00"
  }

  node_pool {
    name       = "default"
    size       = var.vm_sku
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
  }
}
