data "kubernetes_service_v1" "external_lb" {
  metadata {
    name      = local.external_ingress_name
    namespace = local.istio_gateways_namespace
  }

  depends_on = [helm_release.istio_ingressgateway]
}

resource "digitalocean_record" "this" {
  for_each = {
    "A" = data.kubernetes_service_v1.external_lb.status.0.load_balancer.0.ingress[0].ip
  }
  domain = var.dns_domain
  name   = var.name
  type   = each.key
  value  = each.value
  ttl    = 60
}

resource "digitalocean_record" "wildcard" {
  domain = var.dns_domain
  name   = "*.${var.name}"
  type   = "CNAME"
  value  = "${digitalocean_record.this["A"].fqdn}."
  ttl    = 60
}
