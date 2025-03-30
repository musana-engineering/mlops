
resource "azurerm_log_analytics_workspace" "ml" {
  name                = "gbj-ml-prod-la"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  depends_on = [azurerm_resource_group.ml]
}

resource "azurerm_application_insights" "ml" {
  name                = "gbj-ml-prod-appi"
  location            = azurerm_resource_group.ml.location
  resource_group_name = azurerm_resource_group.ml.name
  workspace_id        = azurerm_log_analytics_workspace.ml.id
  application_type    = "web"
  tags                = local.tags

  depends_on = [azurerm_resource_group.ml,
  azurerm_virtual_network.ml]
}

// Key Vault
resource "azurerm_key_vault" "ml" {
  name                            = "gbj-ml-prod-kv"
  location                        = azurerm_resource_group.ml.location
  resource_group_name             = azurerm_resource_group.ml.name
  tenant_id                       = data.azurerm_subscription.current.tenant_id
  sku_name                        = "standard"
  enable_rbac_authorization       = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = ["8.29.228.126", "8.29.109.138"]
    virtual_network_subnet_ids = [azurerm_subnet.ml.id]
  }
  tags = local.tags
  depends_on = [azurerm_resource_group.ml,
    azurerm_virtual_network.ml,
  azurerm_subnet.ml]
}

data "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.ml.name
  depends_on          = [azurerm_private_dns_zone.dns]
}

resource "azurerm_private_endpoint" "kv" {
  name                = "gbj-ml-prod-kv"
  resource_group_name = azurerm_resource_group.ml.name
  location            = azurerm_resource_group.ml.location
  subnet_id           = azurerm_subnet.ml.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["${data.azurerm_private_dns_zone.kv.id}"]
  }
  private_service_connection {
    name                           = "gbj-ml-prod-kv"
    private_connection_resource_id = azurerm_key_vault.ml.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  tags = local.tags

  depends_on = [azurerm_virtual_network.ml, azurerm_subnet.ml,
    azurerm_private_dns_zone.dns,
  azurerm_subnet.ml]
}

resource "azurerm_machine_learning_workspace" "ml" {
  name                          = "gbj-ml-prod-mlws"
  location                      = azurerm_resource_group.ml.location
  resource_group_name           = azurerm_resource_group.ml.name
  application_insights_id       = azurerm_application_insights.ml.id
  key_vault_id                  = azurerm_key_vault.ml.id
  storage_account_id            = azurerm_storage_account.ml.id
  high_business_impact          = true
  tags                          = local.tags
  friendly_name                 = "gbj-ml-prod-mlws"
  public_network_access_enabled = false
  description                   = "Machine Learning Operations"

  #  managed_network {
  #    isolation_mode = "AllowInternetOutbound"
  #  }

  serverless_compute {
    subnet_id         = azurerm_subnet.ml.id
    public_ip_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_resource_group.ml,
    azurerm_key_vault.ml,
    azurerm_virtual_network.ml,
  azurerm_subnet.ml]
}

data "azurerm_private_dns_zone" "workspace" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.ml.name
  depends_on          = [azurerm_private_dns_zone.dns]
}

data "azurerm_private_dns_zone" "notebook" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.ml.name
  depends_on          = [azurerm_private_dns_zone.dns]
}

resource "azurerm_private_endpoint" "workspace" {
  name                = "gbj-ml-prod-mlws"
  resource_group_name = azurerm_resource_group.ml.name
  location            = azurerm_resource_group.ml.location
  subnet_id           = azurerm_subnet.ml.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["${data.azurerm_private_dns_zone.workspace.id}"]
  }
  private_service_connection {
    name                           = "gbj-ml-prod-mlws"
    private_connection_resource_id = azurerm_machine_learning_workspace.ml.id
    is_manual_connection           = false
    subresource_names              = ["amlworkspace"]
  }

  tags = local.tags

  depends_on = [azurerm_virtual_network.ml, azurerm_subnet.ml,
    azurerm_private_dns_zone.dns,
  azurerm_storage_account.ml]
}

resource "azurerm_private_endpoint" "notebooks" {
  name                = "gbj-ml-prod-jnb"
  resource_group_name = azurerm_resource_group.ml.name
  location            = azurerm_resource_group.ml.location
  subnet_id           = azurerm_subnet.ml.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["${data.azurerm_private_dns_zone.notebook.id}"]
  }
  private_service_connection {
    name                           = "gbj-ml-prod-jnb"
    private_connection_resource_id = azurerm_machine_learning_workspace.ml.id
    is_manual_connection           = false
    subresource_names              = ["amlworkspace"]
  }

  tags = local.tags

  depends_on = [azurerm_virtual_network.ml, azurerm_subnet.ml,
    azurerm_private_dns_zone.dns,
  azurerm_storage_account.ml]
}

resource "azurerm_role_assignment" "sa" {
  scope                = azurerm_storage_account.ml.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_machine_learning_workspace.ml.identity[0].principal_id

  depends_on = [azurerm_virtual_network.ml]
}

resource "azurerm_role_assignment" "kv" {
  scope                = azurerm_key_vault.ml.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_machine_learning_workspace.ml.identity[0].principal_id

  depends_on = [azurerm_virtual_network.ml]

}

resource "azurerm_machine_learning_compute_cluster" "ml" {
  name                          = "gbj-ml-prod-clus"
  location                      = azurerm_resource_group.ml.location
  vm_priority                   = "Dedicated"
  vm_size                       = "Standard_DS11_v2"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.ml.id
  subnet_resource_id            = azurerm_subnet.ml.id

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 2
    scale_down_nodes_after_idle_duration = "PT30S"
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_machine_learning_workspace.ml,
  azurerm_virtual_network.ml]
}

resource "azurerm_role_assignment" "cluster" {
  scope                = azurerm_machine_learning_compute_cluster.ml.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_machine_learning_compute_cluster.ml.identity[0].principal_id

  depends_on = [azurerm_machine_learning_compute_cluster.ml,
  azurerm_virtual_network.ml]
}

// Developer Workstation
resource "azurerm_network_interface" "ml" {
  name                = "gbj-ml-prod-vm"
  resource_group_name = azurerm_resource_group.ml.name
  location            = azurerm_resource_group.ml.location

  ip_configuration {
    name                          = "gbj-ml-prod-vm"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.ml.id
  }

  tags = local.tags
}

resource "azurerm_windows_virtual_machine" "ml" {
  name                              = "gbj-ml-prod-vm"
  location                          = azurerm_resource_group.ml.location
  resource_group_name               = azurerm_resource_group.ml.name
  network_interface_ids             = [azurerm_network_interface.ml.id]
  size                              = "Standard_B4ms"
  admin_username                    = "musana.engineering"
  admin_password                    = "MusanaEng_2025"
  vm_agent_platform_updates_enabled = true

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-pro"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  tags = local.tags

  depends_on = [azurerm_virtual_network.ml, azurerm_subnet.ml,
    azurerm_private_dns_zone.dns,
  azurerm_storage_account.ml]
}

resource "azurerm_role_assignment" "vm" {
  scope                = azurerm_machine_learning_workspace.ml.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_virtual_machine.ml.identity[0].principal_id

  depends_on = [azurerm_machine_learning_compute_cluster.ml,
    azurerm_virtual_network.ml,
  azurerm_windows_virtual_machine.ml]
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