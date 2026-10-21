locals {
  agent_kubeconfig = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      cluster = {
        "certificate-authority-data" = base64encode(kubernetes_secret_v1.agent_token.data["ca.crt"])
        server                       = data.terraform_remote_state.infrastructure.outputs.cluster_endpoint
      }
      name = "eks-cluster"
    }]
    contexts = [{
      context = {
        cluster = "eks-cluster"
        user    = "ai-agent"
      }
      name = "debug-context"
    }]
    "current-context" = "debug-context"
    users = [{
      name = "ai-agent"
      user = {
        token = kubernetes_secret_v1.agent_token.data["token"]
      }
    }]
  })
}

output "kubeconfig" {
  value       = local.agent_kubeconfig
  sensitive   = true
  description = "Standalone kubeconfig for the AI agent debugger"
}

output "service_account" {
  value       = kubernetes_service_account_v1.agent.metadata[0].name
  description = "Service account used by the AI agent debugger"
}
