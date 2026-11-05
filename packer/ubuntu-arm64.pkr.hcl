locals {
  build_tags = {
    purpose       = "image-build"
    image_version = var.image_version
    git_sha       = var.git_sha
  }
}

source "azure-arm" "ubuntu_arm64" {
  # Authenticates with the Azure CLI session created by azure/login (OIDC).
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # Temporary VM, disk, NIC, public IP and vnet are created in this existing
  # resource group and removed by Packer when the build finishes.
  build_resource_group_name = var.build_resource_group

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server-arm64"
  image_version   = "latest"
  vm_size         = var.vm_size

  # Publish straight to Azure Compute Gallery (no intermediate managed image).
  # New versions are excluded from "latest" until the smoke test promotes them.
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.gallery_resource_group
    gallery_name         = var.gallery_name
    image_name           = var.image_definition
    image_version        = var.image_version
    replication_regions  = [var.location]
    storage_account_type = "Standard_LRS"
  }
  shared_gallery_image_version_exclude_from_latest = true

  azure_tags = local.build_tags
}

build {
  name    = "ubuntu-24.04-arm64-baseline"
  sources = ["source.azure-arm.ubuntu_arm64"]

  # Let cloud-init finish so apt is not locked. Exit code 2 means "done with
  # recoverable errors", which is acceptable here.
  provisioner "shell" {
    inline = [
      "cloud-init status --wait || [ $? -eq 2 ]",
      "uname -m | grep -qx aarch64",
    ]
  }

  provisioner "ansible" {
    playbook_file = "${path.root}/../ansible/playbook.yml"
    use_proxy     = false
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.root}/../ansible/ansible.cfg",
    ]
    extra_arguments = [
      "--extra-vars", "baseline_image_name=${var.image_definition}",
      "--extra-vars", "baseline_image_version=${var.image_version}",
      "--extra-vars", "baseline_git_sha=${var.git_sha}",
    ]
  }

  # Vulnerability scan of the finished file system.
  provisioner "shell" {
    script = "${path.root}/../scripts/trivy-scan.sh"
    environment_vars = [
      "TRIVY_VERSION=${var.trivy_version}",
      "FAIL_ON_CRITICAL=${var.fail_on_critical}",
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/trivy-report.txt"
    destination = "${path.cwd}/reports/trivy-report.txt"
  }

  # Remove the scanner and generalize the VM. This must be the last step.
  provisioner "shell" {
    inline = [
      "rm -rf /tmp/trivy /tmp/trivy-report.txt /root/.cache/trivy",
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync",
    ]
    inline_shebang  = "/bin/sh -x"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
  }

  post-processor "manifest" {
    output     = "${path.cwd}/reports/packer-manifest.json"
    strip_path = true
    custom_data = {
      image_version = var.image_version
      git_sha       = var.git_sha
    }
  }
}
