variable "east_cluster" {
  type = object({
    name                      = string
    remote_reader_secret_name = string
    kubeconfig = object({
      host                   = string
      client_certificate     = string
      client_key             = string
      cluster_ca_certificate = string
      token                  = string
    })
  })
}

variable "west_cluster" {
  type = object({
    name                      = string
    remote_reader_secret_name = string
    kubeconfig = object({
      host                   = string
      client_certificate     = string
      client_key             = string
      cluster_ca_certificate = string
      token                  = string
    })
  })
}

variable "istio_namespace" {
  type    = string
  default = "istio-system"
}

variable "k8s_sa_name" {
  type    = string
  default = "istio-reader-service-account"
}
