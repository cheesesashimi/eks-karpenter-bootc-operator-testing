resource "kubernetes_secret_v1" "agent_token" {
  metadata {
    name      = "ai-agent-debugger-token"
    namespace = kubernetes_service_account_v1.agent.metadata[0].namespace

    annotations = {
      "kubernetes.io/service-account-token" = "true"
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.agent.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true

  lifecycle {
    # The service-account-token controller adds the token and CA after creation.
    ignore_changes = [data]
  }
}
