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
  name: hello-stavanger
  namespace: ${kubernetes_namespace_v1.example.metadata[0].name}
spec:
  image: ghcr.io/omaen/custom-http-response:main
  port: 5000
  ingresses:
    - hello-stavanger.${var.name}.${var.dns_domain}
  env:
    - name: TEXT_OUTPUT
      value: "Hello from ${var.name} (${var.region})!"
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
