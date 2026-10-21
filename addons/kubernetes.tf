resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      role      = data.terraform_remote_state.infrastructure.outputs.karpenter_node_iam_role_name
      amiFamily = "AL2023"
      amiSelectorTerms = [
        {
          id = data.terraform_remote_state.infrastructure.outputs.karpenter_ami_id
        }
      ]
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = data.terraform_remote_state.infrastructure.outputs.cluster_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = data.terraform_remote_state.infrastructure.outputs.cluster_name
          }
        }
      ]
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.karpenter_instance_types
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r", "t"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            }
          ]
          expireAfter = "720h"
        }
      }
      limits = {
        cpu = "1000"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  })

  depends_on = [kubectl_manifest.karpenter_node_class]
}

resource "kubectl_manifest" "inflate_deployment" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name = "inflate"
    }
    spec = {
      replicas = 0
      selector = {
        matchLabels = {
          app = "inflate"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "inflate"
          }
        }
        spec = {
          terminationGracePeriodSeconds = 0
          securityContext = {
            runAsUser  = 1000
            runAsGroup = 3000
            fsGroup    = 2000
          }
          containers = [
            {
              name  = "inflate"
              image = "public.ecr.aws/eks-distro/kubernetes/pause:3.7"
              resources = {
                requests = {
                  cpu = "1"
                }
              }
              securityContext = {
                allowPrivilegeEscalation = false
              }
            }
          ]
        }
      }
    }
  })
}

resource "kubectl_manifest" "bootc_nodepool_karpenter" {
  yaml_body = yamlencode({
    apiVersion = "node.bootc.dev/v1alpha1"
    kind       = "BootcNodePool"
    metadata = {
      name = "karpenter"
    }
    spec = {
      nodeSelector = {
        matchLabels = {
          "kubernetes.io/os"        = "linux"
          "karpenter.sh/registered" = "true"
        }
      }
      image = {
        ref = local.bootc_os_image
      }
    }
  })

  depends_on = [helm_release.bootc_operator]
}

resource "kubectl_manifest" "bootc_nodepool_default" {
  yaml_body = yamlencode({
    apiVersion = "node.bootc.dev/v1alpha1"
    kind       = "BootcNodePool"
    metadata = {
      name = "default"
    }
    spec = {
      nodeSelector = {
        matchLabels = {
          "kubernetes.io/os" = "linux"
        }
        matchExpressions = [
          {
            key      = "karpenter.sh/registered"
            operator = "DoesNotExist"
          }
        ]
      }
      image = {
        ref = local.bootc_os_image
      }
    }
  })

  depends_on = [helm_release.bootc_operator]
}
