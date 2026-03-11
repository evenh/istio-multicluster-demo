locals {
  skiperator_ns = "skiperator-system"
}

resource "kubernetes_namespace_v1" "skiperator-system" {
  metadata {
    name = local.skiperator_ns
  }
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
      "gcpWorkloadIdentityPool" : "some-pool"
    })
  }
}

data "http" "skiperator_manifests_namespaced" {
  for_each = toset([
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/samples/ns-exclusions-config.yaml",
    "https://raw.githubusercontent.com/kartverket/skiperator/refs/heads/main/tests/cluster-config/rbac.yaml",
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
    # Dependencies
    "https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.85.0/stripped-down-crds.yaml",
    "https://raw.githubusercontent.com/nais/liberator/main/config/crd/bases/nais.io_idportenclients.yaml",
    "https://raw.githubusercontent.com/nais/liberator/main/config/crd/bases/nais.io_maskinportenclients.yaml",
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
        automount_service_account_token = true
        container {
          name  = "skiperator"
          image = "ghcr.io/kartverket/skiperator:v2.13.0"
          args  = ["-l", "-d"]

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
      }
    }
  }
  depends_on = [
    kubectl_manifest.skiperator_docs,
    kubectl_manifest.skiperator_docs_namespaced,
    helm_release.istiod,
    helm_release.istio_ingressgateway,
    helm_release.cert_manager
  ]
}
