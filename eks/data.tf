# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = aws_eks_node_group.main.node_group_name
}

data "aws_autoscaling_group" "main_node_group" {
  name = one(data.aws_eks_node_group.main.resources[0].autoscaling_groups[*].name)
}

data "aws_instances" "main_node_group" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [data.aws_autoscaling_group.main_node_group.name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "external" "bootc_image" {
  program = [
    "bash",
    "${path.module}/scripts/get-bootc-image.sh"
  ]

  query = {
    instance_id = one(data.aws_instances.main_node_group.ids)
  }

  depends_on = [aws_eks_node_group.main]
}
