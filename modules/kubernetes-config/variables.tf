variable "kubeconfig" {
  sensitive = true
  type = object({
    host                   = string
    client_certificate     = string
    client_key             = string
    cluster_ca_certificate = string
    token                  = string
  })
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "dns_domain" {
  type    = string
  default = "retti.cloud"
}

variable "istio_version" {
  type    = string
  default = "1.29.0"
}

