resource "helm_release" "karpenter" {
  namespace        = data.terraform_remote_state.infrastructure.outputs.karpenter_namespace
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  set {
    name  = "settings.clusterName"
    value = data.terraform_remote_state.infrastructure.outputs.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = data.terraform_remote_state.infrastructure.outputs.cluster_name
  }

  set {
    name  = "settings.enableZonalShift"
    value = var.enable_zonal_shift
  }
}

resource "helm_release" "bootc_operator" {
  name             = "bootc-operator"
  chart            = var.bootc_operator_chart_path
  namespace        = "bootc-operator"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  set {
    name  = "image.repository"
    value = var.bootc_operator_image_repo
  }

  set {
    name  = "image.tag"
    value = var.bootc_operator_image_tag
  }
}
