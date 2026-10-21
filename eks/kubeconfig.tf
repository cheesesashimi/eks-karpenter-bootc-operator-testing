locals {
  kubeconfig_path = startswith(pathexpand(var.kubeconfig_path), "/") ? pathexpand(var.kubeconfig_path) : abspath("${path.root}/${var.kubeconfig_path}")
}

resource "terraform_data" "kubeconfig" {
  input = {
    cluster_name = aws_eks_cluster.main.name
    kubeconfig   = local.kubeconfig_path
  }

  triggers_replace = [
    aws_eks_cluster.main.id,
    local.kubeconfig_path,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "$(dirname '${local.kubeconfig_path}')"
      aws eks update-kubeconfig \
        --region '${var.aws_region}' \
        --name '${aws_eks_cluster.main.name}' \
        --kubeconfig '${local.kubeconfig_path}'
    EOT
  }

  depends_on = [aws_eks_node_group.main]
}
