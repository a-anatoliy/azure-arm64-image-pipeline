# Governance: VMs in the workloads resource group must be created from the
# approved gallery. Starts in Audit mode; switch to Deny when ready.

resource "azurerm_resource_group" "workloads" {
  name     = var.workloads_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_policy_definition" "approved_images" {
  name         = "allowed-vm-images-from-gallery"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Virtual machines must use images from the approved compute gallery"

  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
    galleryId = {
      type = "String"
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Compute/virtualMachines" },
        { field = "Microsoft.Compute/imageId", notLike = "[concat(parameters('galleryId'), '/images/*')]" }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "approved_images" {
  name                 = "approved-vm-images"
  resource_group_id    = azurerm_resource_group.workloads.id
  policy_definition_id = azurerm_policy_definition.approved_images.id
  display_name         = "Only images from ${var.gallery_name}"

  parameters = jsonencode({
    effect    = { value = var.image_policy_effect }
    galleryId = { value = azurerm_shared_image_gallery.this.id }
  })
}
