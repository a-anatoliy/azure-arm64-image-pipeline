data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Gallery and image definition
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "gallery" {
  name     = var.gallery_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_shared_image_gallery" "this" {
  name                = var.gallery_name
  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  description         = "Standard ARM64 Linux images"
  tags                = var.tags
}

resource "azurerm_shared_image" "ubuntu_arm64" {
  name                = var.image_definition_name
  gallery_name        = azurerm_shared_image_gallery.this.name
  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  description         = "Ubuntu 24.04 LTS ARM64 with security baseline"

  os_type            = "Linux"
  hyper_v_generation = "V2"
  architecture       = "Arm64"

  identifier {
    publisher = var.image_publisher
    offer     = "ubuntu-24_04-lts-baseline"
    sku       = "server-arm64"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Build resource group and smoke-test network
# Packer creates its temporary VM here; smoke tests use a private subnet
# without public IPs and run checks through "az vm run-command".
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "build" {
  name     = var.build_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "smoke_test" {
  name                = "vnet-image-smoke-test"
  resource_group_name = azurerm_resource_group.build.name
  location            = azurerm_resource_group.build.location
  address_space       = ["10.42.0.0/24"]
  tags                = var.tags
}

resource "azurerm_subnet" "smoke_test" {
  name                 = "snet-smoke-test"
  resource_group_name  = azurerm_resource_group.build.name
  virtual_network_name = azurerm_virtual_network.smoke_test.name
  address_prefixes     = ["10.42.0.0/26"]
}

# ---------------------------------------------------------------------------
# Identity for GitHub Actions (OIDC workload identity federation, no secrets)
# ---------------------------------------------------------------------------

resource "azuread_application" "github" {
  display_name = "github-image-pipeline-${replace(var.github_repository, "/", "-")}"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "github" {
  client_id = azuread_application.github.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.github.id
  display_name   = "github-main-branch"
  description    = "Workflows running on the main branch of ${var.github_repository}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:ref:refs/heads/main"
}

# Least privilege: the pipeline can only change these two resource groups.
resource "azurerm_role_assignment" "gallery" {
  scope                = azurerm_resource_group.gallery.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github.object_id
}

resource "azurerm_role_assignment" "build" {
  scope                = azurerm_resource_group.build.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github.object_id
}
