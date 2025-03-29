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

# Set up Azure ML client
subscription_id = os.environ.get("SUBSCRIPTION_ID")
resource_group = "rg-aml-nonprod"
workspace = "aml-nonprod"

ml_client = MLClient(
    DefaultAzureCredential(), 
    subscription_id=subscription_id,
    resource_group_name=resource_group,
    workspace_name=workspace,
    show_progress=True
)

# Show workspace details
ws = ml_client.workspaces.get(name=workspace)
# print(json.dumps(ws._to_dict(), indent=4, sort_keys=True, default=str))

############### Create Snowflake Dataconnection
# If using username/password, the name/password values should be url-encoded
import urllib.parse
sf_username = urllib.parse.quote(os.environ["SNOWFLAKE_USERNAME"], safe="")
sf_password = urllib.parse.quote(os.environ["SNOWFLAKE_PASSWORD"], safe="")
sf_account = "WRJAZGI-FBA89331.snowflakecomputing.com"
sf_database = "GLOBOJAVA"
sf_warehouse = "ML_WH"
sf_role = "ML_ENG"

target = f"jdbc:snowflake://{sf_account}/?db={sf_database}&warehouse={sf_warehouse}&role={sf_role}"
sf_connection_name = "Snowflake"  # Name of the connection

# Create or update the Snowflake connection
wps_connection = WorkspaceConnection(
    name=sf_connection_name,
    type="snowflake",
    target=target,
    credentials=UsernamePasswordConfiguration(username=sf_username, password=sf_password)
)
ml_client.connections.create_or_update(workspace_connection=wps_connection)

############### Import Data and Register Workspace Dataset
dataset_name = "Sales_Data_Raw"

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
        path="azureml://datastores/workspaceblobstore/paths/snowflake/${{name}}",
        version="1"
    )
    ml_client.data.import_data(data_import=data_import)

############### Consume dataset
import mltable
data_asset = ml_client.data.get("Sales_Data_Raw", version="1")
tbl = mltable.load(data_asset.path)
df = tbl.to_pandas_dataframe()
df.info()
df.describe()
