output "github_variables" {
  description = "Values to store as GitHub Actions repository variables."
  value = {
    AZURE_CLIENT_ID        = azuread_application.github.client_id
    AZURE_TENANT_ID        = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID  = var.subscription_id
    AZURE_LOCATION         = var.location
    GALLERY_RESOURCE_GROUP = azurerm_resource_group.gallery.name
    BUILD_RESOURCE_GROUP   = azurerm_resource_group.build.name
    GALLERY_NAME           = azurerm_shared_image_gallery.this.name
    IMAGE_DEFINITION       = azurerm_shared_image.ubuntu_arm64.name
    SMOKE_TEST_SUBNET_ID   = azurerm_subnet.smoke_test.id
  }
}
