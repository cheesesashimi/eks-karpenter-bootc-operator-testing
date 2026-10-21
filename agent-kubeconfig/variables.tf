variable "kubeconfig_path" {
  type        = string
  default     = "ai-agent-kubeconfig.yaml"
  description = "Path, relative to this stack, where the generated kubeconfig is written"

  validation {
    condition     = !startswith(var.kubeconfig_path, "/")
    error_message = "kubeconfig_path must be relative to the agent-kubeconfig stack."
  }
}
