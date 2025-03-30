
variable "snowflake_username" {}
variable "snowflake_password" {}
variable "snowflake_account" {}
variable "snowflake_database" {}
variable "snowflake_warehouse" {}
variable "snowflake_role" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

data "azurerm_resource_group" "ml" {
  name = "gbj-ml-prod-rg"
}

data "azurerm_machine_learning_workspace" "ml" {
  name                = "gbj-ml-prod-mlws"
  resource_group_name = data.azurerm_resource_group.ml.name
}

resource "null_resource" "create_connection_script" {
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > connections.py      
# Import required libraries
import pandas as pd
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential
from azure.ai.ml.entities import Environment, BuildContext, Data, DataImport, WorkspaceConnection, UsernamePasswordConfiguration
from azure.ai.ml.data_transfer import Database
from azure.ai.ml import automl
from azure.ai.ml.constants import AssetTypes
import os, json
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Create Service Principal credential object
from azure.identity import ClientSecretCredential
credential = ClientSecretCredential(
    tenant_id="${var.tenant_id}",
    client_id="${var.client_id}",
    client_secret="${var.client_secret}"
)

# Set up Azure ML client
subscription_id = "${var.subscription_id}"
resource_group = "${data.azurerm_resource_group.ml.name}"
workspace = "${data.azurerm_machine_learning_workspace.ml.name}"

ml_client = MLClient(
    credential=credential, 
    subscription_id=subscription_id,
    resource_group_name=resource_group,
    workspace_name=workspace,
    show_progress=True
)

# Show workspace details
ws = ml_client.workspaces.get(name=workspace)
# print(json.dumps(ws._to_dict(), indent=4, sort_keys=True, default=str))

# Create Snowflake Dataconnection
# If using username/password, the name/password values should be url-encoded
import urllib.parse
sf_username = urllib.parse.quote("${var.snowflake_username}", safe="")
sf_password = urllib.parse.quote("${var.snowflake_password}", safe="")

target = f"jdbc:snowflake://${var.snowflake_account}.snowflakecomputing.com/?db=${var.snowflake_database}&warehouse=${var.snowflake_warehouse}&role=${var.snowflake_role}"
sf_connection_name = "Snowflake" 

# Create or update the Snowflake connection
wps_connection = WorkspaceConnection(
    name=sf_connection_name,
    type="snowflake",
    target=target,
    credentials=UsernamePasswordConfiguration(username=sf_username, password=sf_password)
)
ml_client.connections.create_or_update(workspace_connection=wps_connection)

# Import Data and Register Workspace Dataset
dataset_name = "GBJ_Raw_SalesData"

try:
    ml_client.data.get(name=dataset_name, version="1")
    print("Dataset with same name already exists")
except:
    print("Registering dataset")
    data_import = DataImport(
        name=dataset_name,
        source=Database(
            connection=sf_connection_name,
            query="SELECT * FROM GLOBOJAVA.SALES.TRANSACTIONS"
        ),
        path=f"azureml://datastores/gbjrawdata/paths/raw/{dataset_name}",
        version="1"
    )
    ml_client.data.import_data(data_import=data_import)
EOF
EOT
  }
}

// Create the Connection
resource "null_resource" "execute_connection_script" {
  provisioner "local-exec" {
    command = <<EOT
# pip install -r requirements.txt --break-system-packages
python3 connections.py
EOT
  }
  depends_on = [null_resource.create_connection_script]
}

