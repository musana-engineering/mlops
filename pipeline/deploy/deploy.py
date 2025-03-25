from azure.ai.ml.entities import Model, Environment, KubernetesOnlineEndpoint, KubernetesOnlineDeployment
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential
from azure.ai.ml.entities import Environment, BuildContext, Data, DataImport, WorkspaceConnection, UsernamePasswordConfiguration
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

# Register the model
model = Model(
    path="model_monthly.pkl",
    name="globojava_demand_forecasting_monthly",
    description="GloboJava monthly demand forecasting model"
)
ml_client.models.create_or_update(model)

# Define the Kubernetes endpoint
endpoint = KubernetesOnlineEndpoint(
    name="globojava-kubernetes-endpoint",
    description="Kubernetes endpoint for GloboJava demand forecasting",
    auth_mode="key"
)
ml_client.online_endpoints.create_or_update(endpoint)

# Define the Kubernetes deployment
deployment = KubernetesOnlineDeployment(
    name="globojava-kubernetes-deployment",
    endpoint_name="globojava-kubernetes-endpoint",
    model=model,
    environment=Environment(name="AzureML-Minimal"),
    code_configuration={"code": ".", "scoring_script": "score.py"},
    instance_type="Standard_DS2_v2",
    instance_count=1
)
ml_client.online_deployments.create_or_update(deployment)