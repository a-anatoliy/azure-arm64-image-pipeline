variable "subscription_id" {
  description = "Azure subscription that hosts the gallery and the build resources."
  type        = string
}

variable "location" {
  description = "Azure region. It must offer ARM64 VM sizes such as Dpsv5."
  type        = string
  default     = "westeurope"
}

variable "github_repository" {
  description = "GitHub repository allowed to run the image pipeline, as owner/name."
  type        = string
}

variable "gallery_resource_group_name" {
  type    = string
  default = "rg-image-gallery"
}

variable "build_resource_group_name" {
  description = "Resource group for temporary build and smoke-test resources."
  type        = string
  default     = "rg-image-build"
}

variable "gallery_name" {
  description = "Azure Compute Gallery name (letters, digits, underscores and periods only)."
  type        = string
  default     = "gal_arm64_images"
}

variable "image_definition_name" {
  type    = string
  default = "ubuntu-24.04-arm64-baseline"
}

variable "image_publisher" {
  description = "Publisher value used in the image definition identifier."
  type        = string
  default     = "a-anatoliy"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "azure-arm64-image-pipeline"
    managed_by = "terraform"
  }
}

variable "workloads_resource_group_name" {
  description = "Resource group where the approved-image policy is enforced."
  type        = string
  default     = "rg-workloads"
}

variable "image_policy_effect" {
  description = "Effect of the approved-image policy: Audit, Deny or Disabled."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.image_policy_effect)
    error_message = "image_policy_effect must be Audit, Deny or Disabled."
  }
}
