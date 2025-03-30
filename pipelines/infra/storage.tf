// Storage Account
resource "azurerm_storage_account" "ml" {
  name                          = "gbjmlprodsa"
  location                      = local.location
  resource_group_name           = azurerm_resource_group.ml.name
  account_tier                  = "Standard"
  min_tls_version               = "TLS1_2"
  https_traffic_only_enabled    = true
  account_replication_type      = "LRS"
  public_network_access_enabled = false
  network_rules {
    default_action             = "Deny"
    ip_rules                   = ["8.29.228.126", "8.29.109.138"]
    virtual_network_subnet_ids = [azurerm_subnet.ml.id]
    bypass                     = ["Logging", "Metrics", "AzureServices"]

    private_link_access {
      endpoint_resource_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourcegroups/${azurerm_resource_group.ml.name}/providers/Microsoft.MachineLearningServices/workspaces/*"
      endpoint_tenant_id   = data.azurerm_subscription.current.tenant_id
    }
  }

  depends_on = [azurerm_resource_group.ml,
    azurerm_virtual_network.ml,
  azurerm_subnet.ml]
}

resource "azurerm_storage_container" "raw" {
  name                  = "raw"
  storage_account_id    = azurerm_storage_account.ml.id
  container_access_type = "private"

  depends_on = [azurerm_resource_group.ml,
    azurerm_virtual_network.ml,
  azurerm_storage_account.ml]
}

resource "azurerm_storage_container" "processed" {
  name                  = "processed"
  storage_account_id    = azurerm_storage_account.ml.id
  container_access_type = "private"

  depends_on = [azurerm_resource_group.ml,
    azurerm_virtual_network.ml,
  azurerm_storage_account.ml]
}

resource "azurerm_machine_learning_datastore_blobstorage" "raw" {
  name                 = "gbjrawdata"
  workspace_id         = azurerm_machine_learning_workspace.ml.id
  storage_container_id = azurerm_storage_container.raw.resource_manager_id
  account_key          = azurerm_storage_account.ml.primary_access_key
  is_default           = true
}

resource "azurerm_machine_learning_datastore_blobstorage" "processed" {
  name                 = "gbjprocesseddata"
  workspace_id         = azurerm_machine_learning_workspace.ml.id
  storage_container_id = azurerm_storage_container.processed.resource_manager_id
  account_key          = azurerm_storage_account.ml.primary_access_key
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.ml.name
  depends_on          = [azurerm_private_dns_zone.dns]
}

resource "azurerm_private_endpoint" "blob" {
  name                = "gbjmlprodsa"
  resource_group_name = azurerm_resource_group.ml.name
  location            = azurerm_resource_group.ml.location
  subnet_id           = azurerm_subnet.ml.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["${data.azurerm_private_dns_zone.blob.id}"]
  }
  private_service_connection {
    name                           = "gbjmlprodsa"
    private_connection_resource_id = azurerm_storage_account.ml.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags = local.tags

  depends_on = [azurerm_virtual_network.ml, azurerm_subnet.ml,
    azurerm_private_dns_zone.dns,
  azurerm_storage_account.ml]
}
