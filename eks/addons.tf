# ------------------------------------------------------------------------------
# EKS Add-ons, Pod Identity, & Access Entry
# ------------------------------------------------------------------------------
resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = var.karpenter_namespace
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn

  depends_on = [aws_eks_addon.pod_identity]
}

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}
