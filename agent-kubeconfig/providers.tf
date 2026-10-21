terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

variable "infrastructure_state_path" {
  type        = string
  default     = "../eks/terraform.tfstate"
  description = "Path to the infrastructure stack state"
}

data "terraform_remote_state" "infrastructure" {
  backend = "local"

  config = {
    path = var.infrastructure_state_path
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infrastructure.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infrastructure.outputs.cluster_name]
    command     = "aws"
  }
}
