variable "karpenter_version" {
  type        = string
  default     = "1.15.0"
  description = "Karpenter version"
}

variable "karpenter_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EC2 instance types Karpenter may provision"
}

variable "enable_zonal_shift" {
  type        = bool
  default     = false
  description = "Enable Karpenter zonal shift settings"
}

variable "bootc_operator_chart_path" {
  type        = string
  nullable    = false
  description = "Local bootc-operator chart path; set this in a tfvars file"

  validation {
    condition     = length(trimspace(var.bootc_operator_chart_path)) > 0
    error_message = "bootc_operator_chart_path must not be empty. Set it in a tfvars file."
  }
}

variable "bootc_operator_image_repo" {
  type        = string
  default     = "quay.io/zzlotnik/testing"
  description = "bootc-operator image repository"
}

variable "bootc_operator_image_tag" {
  type        = string
  default     = "bootc-operator"
  description = "bootc-operator image tag"
}

variable "bootc_os_image" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional override for the Bootc OS image reference"
}
