# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_eks_node_group" "main" {
  cluster_name    = data.terraform_remote_state.infrastructure.outputs.cluster_name
  node_group_name = "${data.terraform_remote_state.infrastructure.outputs.cluster_name}-ng"
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

  depends_on = [data.aws_eks_node_group.main]
}
