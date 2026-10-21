resource "kubernetes_service_account_v1" "agent" {
  metadata {
    name      = "ai-agent-debugger"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_v1" "agent" {
  metadata {
    name = "ai-agent-debugger-role"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "events"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["delete"]
  }

  rule {
    api_groups     = ["apiextensions.k8s.io"]
    resources      = ["customresourcedefinitions"]
    resource_names = ["nodeclaims.karpenter.sh"]
    verbs          = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["node.bootc.dev"]
    resources  = ["bootcnodepools", "bootcnodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["node.bootc.dev"]
    resources  = ["bootcnodepools"]
    verbs      = ["patch"]
  }

  rule {
    api_groups = ["events.k8s.io"]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments/scale", "daemonsets/scale"]
    verbs      = ["get", "patch", "update"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["karpenter.sh", "karpenter.k8s.aws"]
    resources  = ["nodepools", "nodeclaims", "ec2nodeclasses"]
    verbs      = ["get", "list", "watch", "patch"]
  }

  rule {
    api_groups = ["karpenter.sh"]
    resources  = ["nodeclaims"]
    verbs      = ["delete"]
  }

  rule {
    api_groups = ["bootc.openshift.io", "bootc.dev"]
    resources  = ["bootcnodes", "bootcnodepools"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "agent" {
  metadata {
    name = "ai-agent-debugger-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.agent.metadata[0].name
    namespace = kubernetes_service_account_v1.agent.metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.agent.metadata[0].name
  }
}

resource "kubernetes_role_v1" "agent_karpenter_e2e" {
  metadata {
    name      = "ai-agent-debugger-karpenter-e2e"
    namespace = "default"
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets"]
    verbs      = ["get", "list", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["list"]
  }
}

resource "kubernetes_role_binding_v1" "agent_karpenter_e2e" {
  metadata {
    name      = "ai-agent-debugger-karpenter-e2e"
    namespace = kubernetes_role_v1.agent_karpenter_e2e.metadata[0].namespace
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.agent.metadata[0].name
    namespace = kubernetes_service_account_v1.agent.metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.agent_karpenter_e2e.metadata[0].name
  }
}
