locals {
  # kubeconfig for EAST, to be stored in WEST
  east_kubeconfig = templatefile("${path.module}/kubeconfig.tmpl", {
    name   = var.east_cluster.name
    server = var.east_cluster.kubeconfig.host
    ca     = base64encode(data.kubernetes_secret_v1.east_viewer_token.data["ca.crt"])
    token  = data.kubernetes_secret_v1.east_viewer_token.data["token"]
  })

  # kubeconfig for WEST, to be stored in EAST
  west_kubeconfig = templatefile("${path.module}/kubeconfig.tmpl", {
    name   = var.west_cluster.name
    server = var.west_cluster.kubeconfig.host
    ca     = base64encode(data.kubernetes_secret_v1.west_viewer_token.data["ca.crt"])
    token  = data.kubernetes_secret_v1.west_viewer_token.data["token"]
  })
}

data "kubernetes_secret_v1" "east_viewer_token" {
  provider = kubernetes.east
  metadata {
    name      = var.east_cluster.remote_reader_secret_name
    namespace = var.istio_namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.k8s_sa_name
    }
  }

  depends_on = [var.east_cluster]
}

data "kubernetes_secret_v1" "west_viewer_token" {
  provider = kubernetes.west
  metadata {
    name      = var.west_cluster.remote_reader_secret_name
    namespace = var.istio_namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.k8s_sa_name
    }
  }

  depends_on = [var.west_cluster]
}

# The actual secrets needed for multicluster communication
resource "kubernetes_secret_v1" "istio_remote_east_in_west" {
  provider = kubernetes.west
  metadata {
    name      = "istio-remote-secret-${var.east_cluster.name}"
    namespace = var.istio_namespace
    labels = {
      "istio/multiCluster" = "true"
    }
    annotations = {
      "networking.istio.io/cluster" = var.east_cluster.name
    }
  }

  data = {
    "${var.east_cluster.name}" = local.east_kubeconfig
  }
}

resource "kubernetes_secret_v1" "istio_remote_west_in_east" {
  provider = kubernetes.east
  metadata {
    name      = "istio-remote-secret-${var.west_cluster.name}"
    namespace = var.istio_namespace
    labels = {
      "istio/multiCluster" = "true"
    }
    annotations = {
      "networking.istio.io/cluster" = var.west_cluster.name
    }
  }
  data = {
    "${var.west_cluster.name}" = local.west_kubeconfig
  }
}
