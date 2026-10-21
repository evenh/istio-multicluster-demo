locals {
  skiperator_ns             = "skiperator-system"
  webhook_serving_cert_name = "skiperator-webhook-server-cert"
}

resource "kubernetes_namespace_v1" "skiperator-system" {
  metadata {
    name = local.skiperator_ns
  }
}

resource "kubectl_manifest" "skiperator_selfsigned" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: skiperator-selfsigned
  namespace: ${kubernetes_namespace_v1.skiperator-system.metadata[0].name}
spec:
  selfSigned: {}
YAML

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "skiperator_webhook_ca" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: skiperator-webhook-ca
  namespace: ${kubernetes_namespace_v1.skiperator-system.metadata[0].name}
spec:
  isCA: true
  commonName: skiperator-webhook-ca
  duration: 43800h # 5 years
  renewBefore: 720h # 30 days before expiry
  secretName: skiperator-webhook-ca
  issuerRef:
    name: skiperator-selfsigned
    kind: Issuer
YAML

  depends_on = [kubectl_manifest.skiperator_selfsigned]
}

resource "kubectl_manifest" "skiperator_webhook_ca_issuer" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: skiperator-webhook-ca-issuer
  namespace: ${kubernetes_namespace_v1.skiperator-system.metadata[0].name}
spec:
  ca:
    secretName: skiperator-webhook-ca
YAML

  depends_on = [kubectl_manifest.skiperator_webhook_ca]
}

resource "kubectl_manifest" "skiperator_webhook_serving_cert" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: skiperator-webhook-serving-cert
  namespace: ${kubernetes_namespace_v1.skiperator-system.metadata[0].name}
spec:
  secretName: ${local.webhook_serving_cert_name}
  dnsNames:
    - skipjob-conversion-webhook.skiperator-system.svc
    - skipjob-conversion-webhook.skiperator-system.svc.cluster.local
  issuerRef:
    name: skiperator-webhook-ca-issuer
    kind: Issuer
  usages:
    - server auth
    - digital signature
    - key encipherment
YAML

  depends_on = [kubectl_manifest.skiperator_webhook_ca_issuer]
}

resource "kubernetes_service_account_v1" "skiperator" {
  metadata {
    name      = "skiperator"
    namespace = kubernetes_namespace_v1.skiperator-system.metadata[0].name
  }
  automount_service_account_token = false
}

resource "kubernetes_config_map_v1" "skiperator-config" {
  metadata {
    name      = "skiperator-config"
    namespace = kubernetes_namespace_v1.skiperator-system.metadata[0].name
  }

  data = {
    "config.json" = jsonencode({
      "topologyKeys" : [
        "kubernetes.io/hostname",
      ],
      "leaderElection" : true,
      "leaderElectionNamespace" : "skiperator-system",
      "concurrentReconciles" : 1,
      "isDeployment" : true,
      "logLevel" : "debug",
      "registrySecretRefs" : [],
      "clusterCIDRExclusionEnabled" : true,
      "clusterCIDRMap" : {
        "clusters" : [
          {
            "name" : "test-cluster-1",
            "controlPlaneCIDRs" : [
              "10.40.10.0/25"
            ],
            "workerNodeCIDRs" : [
              "10.40.10.0/24"
            ]
          }
        ]
      },
      "gcpIdentityProvider" : "some-provider",
      "gcpWorkloadIdentityPool" : "some-pool",
      "enableWebhooks" : true
    })
  }
}

data "http" "skiperator_manifests_namespaced" {
  for_each = toset([
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/samples/ns-exclusions-config.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/tests/cluster-config/rbac.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/config/webhook/service.yaml",
  ])

  url = each.key
}

data "http" "skiperator_manifests" {
  for_each = toset([
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/config/crd/skiperator.kartverket.no_applications.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/config/crd/skiperator.kartverket.no_routings.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/config/crd/skiperator.kartverket.no_skipjobs.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/config/rbac/role.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/config/static/priorities.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/config/webhook/manifest.yaml",
    # Dependencies
    "https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.85.0/stripped-down-crds.yaml",
    "https://raw.githubusercontent.com/nais/liberator/main/config/crd/bases/nais.io_idportenclients.yaml",
    "https://raw.githubusercontent.com/nais/liberator/main/config/crd/bases/nais.io_maskinportenclients.yaml",
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml",
  ])

  url = each.key
}

# 1) Split every fetched file into individual documents
data "kubectl_file_documents" "skiperator_docs" {
  for_each = data.http.skiperator_manifests
  content  = each.value.body
}

data "kubectl_file_documents" "skiperator_docs_namespaced" {
  for_each = data.http.skiperator_manifests_namespaced
  content  = each.value.body
}


locals {
  skiperator_docs = merge([
    for file, d in data.kubectl_file_documents.skiperator_docs :
    {
      for idx, doc in d.documents :
      "cluster:${file}:${idx}" => doc
      if trimspace(doc) != ""
    }
  ]...)

  skiperator_docs_namespaced = merge([
    for file, d in data.kubectl_file_documents.skiperator_docs_namespaced :
    {
      for idx, doc in d.documents :
      "ns:${file}:${idx}" => doc
      if trimspace(doc) != ""
    }
  ]...)
}

resource "kubectl_manifest" "skiperator_docs" {
  for_each          = local.skiperator_docs
  yaml_body         = each.value
  server_side_apply = true
  # Override DigitalOcean's older CRDs only for the Gateway API bundle.
  force_conflicts = startswith(each.key, "cluster:https://github.com/kubernetes-sigs/gateway-api/")

  depends_on = [kubectl_manifest.skiperator_webhook_serving_cert]
}

resource "kubectl_manifest" "skiperator_docs_namespaced" {
  for_each          = local.skiperator_docs_namespaced
  yaml_body         = each.value
  server_side_apply = true

  depends_on = [
    kubernetes_namespace_v1.skiperator-system,
    kubernetes_service_account_v1.skiperator,
    kubectl_manifest.skiperator_docs
  ]
}

resource "kubernetes_deployment_v1" "skiperator" {
  metadata {
    name      = "skiperator"
    namespace = local.skiperator_ns
    labels = {
      app = "skiperator"
    }
  }

  spec {
    replicas               = 2
    revision_history_limit = 0

    selector {
      match_labels = {
        app = "skiperator"
      }
    }

    template {
      metadata {
        labels = {
          app = "skiperator"
        }
      }

      spec {
        service_account_name            = kubernetes_service_account_v1.skiperator.metadata.0.name
        priority_class_name             = "skip-critical"
        automount_service_account_token = true

        security_context {
          supplemental_groups = [65532]
          fs_group            = 65532
          run_as_user         = 65532
          run_as_group        = 65532
          run_as_non_root     = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "skiperator"
          image = "ghcr.io/kartverket/skiperator:v2.19.0"
          args = [
            "--webhook-cert-dir=/etc/webhook-certs",
            "--webhook-host=0.0.0.0",
          ]

          security_context {
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
            run_as_user                = 65532
            run_as_group               = 65532
            run_as_non_root            = true
            privileged                 = false

            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }

          volume_mount {
            mount_path = "/etc/webhook-certs"
            name       = "webhook-certs"
            read_only  = true
          }

          port {
            name           = "metrics"
            container_port = 8181
          }

          port {
            name           = "probes"
            container_port = 8081
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "probes"
            }
          }

          readiness_probe {
            http_get {
              path = "/readyz"
              port = "probes"
            }
          }
        }

        volume {
          name = "webhook-certs"
          secret {
            secret_name  = local.webhook_serving_cert_name
            default_mode = "0400"
            optional     = false
          }
        }
      }
    }
  }
  depends_on = [
    kubectl_manifest.skiperator_docs,
    kubectl_manifest.skiperator_docs_namespaced,
    helm_release.istiod,
    helm_release.istio_ingressgateway,
    helm_release.cert_manager,
    kubectl_manifest.skiperator_webhook_serving_cert
  ]
}
