locals {
  location            = "eastus2"
  tenant_id           = "2f1f01b6-2930-4e0d-9a49-26873accbaae"
  user_object_id      = "jim@musana.engineering"
  vnet_address_space  = ["10.144.0.0/16"]
  bastion_subnet_cidr = ["10.144.255.240/28"]
  ml_subnet_cidr      = ["10.144.192.0/19"]

  private_dns_zones = [
    "privatelink.api.azureml.ms",
    "privatelink.blob.core.windows.net",
    "privatelink.eastus2.azmk8s.io",
    "musana.engineering",
    "privatelink.file.core.windows.net",
    "privatelink.notebooks.azure.net",
  "privatelink.vaultcore.azure.net"]

  tags = {
    provisioner = "terraform"
    environment = "prod"
    project     = "ml-demand-forecasting"
  }
}
