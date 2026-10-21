resource "local_sensitive_file" "kubeconfig" {
  content              = local.agent_kubeconfig
  filename             = "${path.module}/${var.kubeconfig_path}"
  file_permission      = "0600"
  directory_permission = "0700"
}
