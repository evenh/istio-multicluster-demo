locals {
  cert_manager_ns = "cert-manager"
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = local.cert_manager_ns
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.19.0"

  create_namespace = true
  wait             = true
  atomic           = true
  cleanup_on_fail  = true

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
    })
  ]
}

resource "random_pet" "cluster-issuer-id" {
  length = 2
}

resource "kubectl_manifest" "cluster-issuer" {
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cluster-issuer
spec:
  acme:
    email: skip+istio-multicluster-${random_pet.cluster-issuer-id.id}@kartverket.no
    privateKeySecretRef:
      name: cluster-issuer-account-key
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - http01:
        ingress:
          class: istio
YAML
  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_secret_v1" "root_ca" {
  metadata {
    name      = "skip-root-ca"
    namespace = local.cert_manager_ns
  }

  data = {
    "ca.crt"  = file("${path.module}/../../files/root_ca/root.crt")
    "tls.crt" = file("${path.module}/../../files/root_ca/root.crt")
    "tls.key" = file("${path.module}/../../files/root_ca/root.key")
  }

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "selfsigned_intermediate_ca" {
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-intermediate-ca
spec:
  ca:
    secretName: skip-root-ca
YAML
  depends_on = [kubernetes_secret_v1.root_ca]
}
