import json
import joblib
import pandas as pd
from azureml.core.model import Model


def init():
    global model
    model_path = Model.get_model_path("globojava_demand_forecasting_monthly")
    model = joblib.load(model_path)

def run(raw_data):
    data = json.loads(raw_data)["data"]
    input_data = pd.DataFrame(data)
    predictions = model.predict(input_data)
    return predictions.tolist()