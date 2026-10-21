output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "Endpoint for EKS control plane"
}

output "cluster_certificate_authority" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
  description = "Base64-encoded EKS cluster CA"
}

output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "EKS Cluster Name"
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS region containing the infrastructure"
}

output "karpenter_namespace" {
  value       = var.karpenter_namespace
  description = "Kubernetes namespace for Karpenter"
}

output "kubeconfig_path" {
  value       = local.kubeconfig_path
  description = "Local path where the EKS kubeconfig was written"
}

output "karpenter_iam_role_arn" {
  value       = aws_iam_role.karpenter_controller.arn
  description = "IAM Role ARN utilized by Karpenter Controller"
}

output "karpenter_node_iam_role_arn" {
  value       = aws_iam_role.karpenter_node.arn
  description = "IAM Role ARN utilized by Karpenter Nodes"
}

output "karpenter_node_iam_role_name" {
  value       = aws_iam_role.karpenter_node.name
  description = "IAM Role name utilized by Karpenter Nodes"
}

output "karpenter_ami_id" {
  value       = var.ami_id
  description = "AMI selected for Karpenter nodes"
}

output "bootc_os_image" {
  value       = data.external.bootc_image.result.image_ref
  description = "Bootc OS image reference reported by the initial node"
}
