locals {
  location       = "eastus2"
  tenant_id      = "2f1f01b6-2930-4e0d-9a49-26873accbaae"
  user_object_id = "jim@musana.engineering"

  tags = {
    provisioner = "terraform"
    environment = "nonprod"
    project     = "aml"
  }
}

resource "azurerm_resource_group" "ml" {
  name     = "gbj-aml-prod-rg"
  location = local.location
  tags     = local.tags
}

resource "azurerm_application_insights" "ml" {
  name                = "gbj-aml-prod-appi"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name
  application_type    = "web"
  tags                = local.tags

  depends_on = [azurerm_resource_group.ml]
}

resource "azurerm_key_vault" "ml" {
  name                            = "gbj-aml-prod-kv"
  location                        = azurerm_resource_group.ml.location
  resource_group_name             = azurerm_resource_group.ml.name
  tenant_id                       = local.tenant_id
  sku_name                        = "standard"
  enable_rbac_authorization       = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  tags                            = local.tags
  depends_on                      = [azurerm_resource_group.ml]
}

resource "azurerm_storage_account" "ml" {
  name                       = "gbjamlprodsa"
  location                   = local.location
  resource_group_name        = azurerm_resource_group.ml.name
  account_tier               = "Standard"
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true
  account_replication_type   = "LRS"

  depends_on = [azurerm_resource_group.ml]
}

resource "azurerm_storage_container" "main" {
  name                  = "datasets"
  storage_account_id    = azurerm_storage_account.ml.id
  container_access_type = "private"

  depends_on = [azurerm_resource_group.ml]
}

resource "azurerm_machine_learning_workspace" "ml" {
  name                          = "gbj-aml-prod-mlws"
  location                      = azurerm_resource_group.ml.location
  resource_group_name           = azurerm_resource_group.ml.name
  application_insights_id       = azurerm_application_insights.ml.id
  key_vault_id                  = azurerm_key_vault.ml.id
  storage_account_id            = azurerm_storage_account.ml.id
  high_business_impact          = true
  tags                          = local.tags
  friendly_name                 = "nonprod"
  public_network_access_enabled = true
  description                   = "Machine Learning Operations"

  #  managed_network {
  #    isolation_mode = "AllowInternetOutbound"
  #  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_resource_group.ml,
  azurerm_key_vault.ml]
}

resource "azurerm_role_assignment" "sa" {
  scope                = azurerm_storage_account.ml.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_machine_learning_workspace.ml.identity[0].principal_id
}

resource "azurerm_role_assignment" "kv" {
  scope                = azurerm_key_vault.ml.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_machine_learning_workspace.ml.identity[0].principal_id

}

resource "azurerm_machine_learning_compute_cluster" "ml" {
  name                          = "gbj-aml-prod-clus"
  location                      = azurerm_resource_group.ml.location
  vm_priority                   = "Dedicated"
  vm_size                       = "Standard_DS11_v2"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.ml.id
  #  subnet_resource_id            = data.azurerm_subnet.ml.id

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 2
    scale_down_nodes_after_idle_duration = "PT30S" # 30 seconds
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_machine_learning_workspace.ml]
}

resource "azurerm_role_assignment" "cluster" {
  scope                = azurerm_machine_learning_compute_cluster.ml.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_machine_learning_compute_cluster.ml.identity[0].principal_id

  depends_on = [azurerm_machine_learning_compute_cluster.ml]
}


/*
resource "azurerm_machine_learning_inference_cluster" "example" {
  name                  = "example"
  location              = azurerm_resource_group.example.location
  cluster_purpose       = "FastProd"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.example.id
  description           = "This is an example cluster used with Terraform"

  machine_learning_workspace_id = azurerm_machine_learning_workspace.example.id

  tags = {
    "stage" = "example"
  }
}
*/