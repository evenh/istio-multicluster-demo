locals {
  istio_repo               = "https://istio-release.storage.googleapis.com/charts"
  istio_namespace          = "istio-system"
  istio_gateways_namespace = "istio-gateways"
  hub                      = "gcr.io/istio-release"

  external_hostname     = "${var.name}.${var.dns_domain}"
  external_ingress_name = "istio-ingress-external"
  eastwest_ingress_name = "istio-eastwest"
}

# Required namespaces
resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = local.istio_namespace
    labels = {
      "topology.istio.io/network" : var.region
      "istio.io/rev" = "default"
    }
  }
}

resource "kubernetes_namespace" "istio_gateways" {
  metadata {
    name = local.istio_gateways_namespace
    labels = {
      "topology.istio.io/network" : var.region
      "istio.io/rev" = "default"
    }
  }
}

# Charts
resource "helm_release" "istio_base" {
  name       = "istio-base"
  namespace  = local.istio_namespace
  repository = local.istio_repo
  chart      = "base"
  version    = var.istio_version

  create_namespace = false
  wait             = true
  atomic           = true
  cleanup_on_fail  = true
}

resource "helm_release" "istio_cni" {
  name       = "istio-cni"
  namespace  = "kube-system"
  repository = local.istio_repo
  chart      = "cni"
  version    = var.istio_version

  values = [
    yamlencode({
      global = {
        hub = local.hub
      }
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  namespace  = local.istio_namespace
  repository = local.istio_repo
  chart      = "istiod"
  version    = var.istio_version

  # Minimal sane defaults; customize meshConfig as needed
  values = [
    yamlencode({
      global = {
        logAsJson = true
        multiCluster = {
          clusterName = var.name
          enabled     = true
        }
        variant = "distroless"
        hub     = local.hub
        meshID  = "worldwide"
        network = var.region
        proxy = {
          holdApplicationUntilProxyStarts = true
          clusterDomain                   = "cluster.local"
          privileged                      = false
          resources = {
            requests = {
              cpu    = "1m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1024Mi"
            }
          }
        }
      }
      pilot = {
        cni = {
          enabled = true
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        env = {
          "PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY"   = true
          "PILOT_ENABLE_PROTOCOL_SNIFFING_FOR_INBOUND"  = true
          "PILOT_ENABLE_PROTOCOL_SNIFFING_FOR_OUTBOUND" = true
          "AUTO_RELOAD_PLUGIN_CERTS"                    = true
        }
      }
      meshConfig = {
        accessLogFile     = "/dev/stdout"
        accessLogEncoding = "JSON"
        localityLbSetting = {
          enabled          = true
          failoverPriority = ["topology.istio.io/network"]
        }
      }
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true

  depends_on = [
    helm_release.istio_base,
    helm_release.istio_cni,
    kubectl_manifest.intermediate_ca
  ]
}

resource "kubernetes_secret_v1" "viewer-token" {
  type = "kubernetes.io/service-account-token"
  metadata {
    name      = "viewer-token"
    namespace = local.istio_namespace
    annotations = {
      "kubernetes.io/service-account.name" = "istio-reader-service-account"
    }
  }

  depends_on = [helm_release.istiod]
}

resource "helm_release" "istio_ingressgateway" {
  name       = "istio-ingress-external"
  namespace  = local.istio_gateways_namespace
  repository = local.istio_repo
  chart      = "gateway"
  version    = var.istio_version

  # Configure a public-facing LoadBalancer with common ports
  values = [
    yamlencode({
      global = {
        hub          = local.hub
        replicaCount = 1
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      autoscaling = {
        enabled                        = true
        minReplicas                    = 1
        maxReplicas                    = 3
        targetCPUUtilizationPercentage = 80
      }

      podDisruptionBudget = {
        minAvailable = "50%"
      }

      terminationGracePeriodSeconds = 30

      env = {
        "EXIT_ON_ZERO_ACTIVE_CONNECTIONS" = false
      }

      labels = {
        app   = "istio-ingress-external"
        istio = "ingressgateway"
      }

      service = {
        type           = "LoadBalancer"
        ipFamilies     = ["IPv4"]
        ipFamilyPolicy = "SingleStack"
        annotations = {
          "service.beta.kubernetes.io/do-loadbalancer-name"                  = local.external_hostname
          "service.beta.kubernetes.io/do-loadbalancer-protocol"              = "tcp"
          "service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol" = "true"
        }

        ports = [
          {
            name       = "status-port"
            port       = 15021
            targetPort = 15021
          },
          {
            name       = "http2"
            port       = 80
            targetPort = 8080
          },
          {
            name       = "https"
            port       = 443
            targetPort = 8443
          }
        ]
        # Optional if you need source IP preservation on some LBs:
        # externalTrafficPolicy = "Local"
      }

      # Give this gateway the standard label so Gateway resources can select it
      labels = {
        app   = "istio-ingress-external"
        istio = "ingressgateway"
      }

      # Set a predictable name for the Deployment/Service objects
      name = "istio-ingress-external"
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true

  depends_on = [helm_release.istiod]
}

resource "kubectl_manifest" "proxy_protocol" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: proxy-protocol
  namespace: ${local.istio_namespace}
spec:
  configPatches:
    - applyTo: LISTENER_FILTER
      patch:
        operation: INSERT_FIRST
        value:
          name: proxy_protocol
          typed_config:
            "@type": "type.googleapis.com/envoy.extensions.filters.listener.proxy_protocol.v3.ProxyProtocol"
            allow_requests_without_proxy_protocol: true
  workloadSelector:
    labels:
      istio: ingressgateway
YAML
  depends_on = [
    helm_release.istio_base,
    helm_release.istiod
  ]
}

resource "kubectl_manifest" "intermediate_ca" {
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cacerts
  namespace: ${local.istio_namespace}
spec:
  commonName: istiod.istio-system.svc
  dnsNames:
    - istiod.istio-system.svc
  duration: 720h
  isCA: true
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: selfsigned-intermediate-ca
  renewBefore: 360h
  secretName: cacerts
  usages:
    - digital signature
    - key encipherment
    - cert sign
YAML
  depends_on = [kubectl_manifest.selfsigned_intermediate_ca]
}

resource "helm_release" "istio_eastwestgateway" {
  name       = "istio-eastwest"
  namespace  = local.istio_gateways_namespace
  repository = local.istio_repo
  chart      = "gateway"
  version    = var.istio_version

  # Configure a public-facing LoadBalancer with common ports
  values = [
    yamlencode({
      global = {
        hub          = local.hub
        replicaCount = 1
      }

      networkGateway = var.region

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      autoscaling = {
        enabled                        = true
        minReplicas                    = 1
        maxReplicas                    = 3
        targetCPUUtilizationPercentage = 80
      }

      podDisruptionBudget = {
        minAvailable = "50%"
      }

      labels = {
        app   = "istio-eastwest"
        istio = "eastwestgateway"
      }

      service = {
        type           = "LoadBalancer"
        ipFamilies     = ["IPv4"]
        ipFamilyPolicy = "SingleStack"
        annotations = {
          "service.beta.kubernetes.io/do-loadbalancer-name"                  = "ewgw.${local.external_hostname}"
          "service.beta.kubernetes.io/do-loadbalancer-protocol"              = "tcp"
          "service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol" = "false"
        }

        ports = [
          {
            name       = "status-port"
            port       = 15021
            targetPort = 15021
          },
          {
            name       = "tls"
            port       = 15443
            targetPort = 15443
          },
          {
            name       = "tls-istiod"
            port       = 15012
            targetPort = 15012
          },
          {
            name       = "tls-webhook"
            port       = 15017
            targetPort = 15017
          }
        ]
      }

      labels = {
        app   = "istio-eastwest"
        istio = "eastwestgateway"
      }

      name = local.eastwest_ingress_name
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true

  depends_on = [helm_release.istiod]
}

resource "kubectl_manifest" "expose-services" {
  yaml_body  = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: cross-network-gateway
  namespace: ${local.istio_gateways_namespace}
spec:
  selector:
    istio: eastwestgateway
  servers:
    - hosts:
        - '*.local'
      port:
        name: tls
        number: 15443
        protocol: TLS
      tls:
        mode: AUTO_PASSTHROUGH
YAML
  depends_on = [helm_release.istio_eastwestgateway]
}
