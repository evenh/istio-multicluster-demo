variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "k8s_version" {
  type    = string
  default = "1.35.9-do.1"
}

variable "vm_sku" {
  type    = string
  default = "s-2vcpu-2gb" // s-4vcpu-8gb
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 3
}

variable "vpc_id" {
  type = number
}
