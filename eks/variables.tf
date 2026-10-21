variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the EKS cluster; set this in a tfvars file"

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name must not be empty. Set it in a tfvars file."
  }
}

variable "kubeconfig_path" {
  type        = string
  default     = "../kubeconfig"
  description = "Local path where the EKS kubeconfig should be written; relative paths are resolved from the eks module"
}

variable "node_group_desired_size" {
  type        = number
  default     = 1
  description = "Desired number of nodes in the managed node group"
}

variable "node_group_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EC2 instance types for the managed node group"
}

variable "k8s_version" {
  type        = string
  default     = "1.36"
  description = "Kubernetes version"
}

variable "ami_id" {
  type        = string
  default     = "ami-056d5e72aa5cf51f1"
  description = "AMI ID for managed and Karpenter node bootstrap"
}

variable "karpenter_namespace" {
  type        = string
  default     = "kube-system"
  description = "Kubernetes namespace for Karpenter"
}
