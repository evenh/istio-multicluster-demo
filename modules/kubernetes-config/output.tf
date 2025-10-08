output "remote_reader_secret_name" {
  value = kubernetes_secret_v1.viewer-token.metadata[0].name
}
