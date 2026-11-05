variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "build_resource_group" {
  description = "Existing resource group for the temporary build VM."
  type        = string
}

variable "gallery_resource_group" {
  type = string
}

variable "gallery_name" {
  type = string
}

variable "image_definition" {
  type = string
}

variable "image_version" {
  description = "Gallery image version, Major.Minor.Patch with integers (e.g. 2026.1105.7)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_version))
    error_message = "The image_version must look like 2026.1105.7."
  }
}

variable "vm_size" {
  description = "ARM64 VM size used for the build (Ampere Altra Dpsv5 by default)."
  type        = string
  default     = "Standard_D2ps_v5"
}

variable "git_sha" {
  type    = string
  default = "unknown"
}

variable "trivy_version" {
  type    = string
  default = "0.57.1"
}

variable "fail_on_critical" {
  description = "Fail the build if Trivy finds fixable CRITICAL vulnerabilities."
  type        = bool
  default     = false
}
