resource "kubernetes_namespace_v1" "example" {
  metadata {
    name = "example"
    labels = {
      "istio.io/rev" = "default"
    }
  }
}

resource "kubectl_manifest" "demo_app" {
  yaml_body = <<YAML
apiVersion: skiperator.kartverket.no/v1alpha1
kind: Application
metadata:
  name: talk-demo
  namespace: ${kubernetes_namespace_v1.example.metadata[0].name}
spec:
  image: ghcr.io/omaen/custom-http-response:main
  port: 5000
  routingProvider: Standard
  ingresses:
    - bergen.${var.name}.${var.dns_domain}
  env:
    - name: TEXT_OUTPUT
      value: "Hei Cloud Native Days Norway 👋 Hilsen ${var.region}"
YAML
  depends_on = [
    kubernetes_deployment_v1.skiperator
  ]
}

resource "kubernetes_network_policy_v1" "allow-eastwest-to-demo" {
  metadata {
    name      = "allow-eastwest-traffic-to-ns"
    namespace = kubernetes_namespace_v1.example.metadata[0].name
  }

  spec {
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = local.istio_gateways_namespace
          }
        }

        pod_selector {
          match_labels = {
            "istio" = "eastwestgateway"
          }
        }
      }
    }

    # Everything in the namespace
    pod_selector {
    }
  }
}

resource "kubernetes_network_policy_v1" "allow-ingress-to-acme-solver" {
  metadata {
    name      = "allow-ingress-to-acme-solver"
    namespace = kubernetes_namespace_v1.example.metadata[0].name
  }

  spec {
    policy_types = ["Ingress"]

    pod_selector {
      match_labels = {
        "acme.cert-manager.io/http01-solver" = "true"
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = local.istio_gateways_namespace
          }
        }

        pod_selector {
          match_labels = {
            app = local.external_ingress_name
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8089"
      }
    }
  }
}
