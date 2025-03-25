import requests
import json

# Define input data
input_data = {
    "data": [
        {
            "StoreID": "STORE101",
            "Country": "USA",
            "City": "New York",
            "Price": 4.00,
            "Weather": "Cold",
            "Promotion": "Yes",
            "Holiday": "Yes"
        }
    ]
}

# Make a request to the web service
scoring_uri = "http://<KUBERNETES_ENDPOINT_URI>/score"  # Replace with your Kubernetes endpoint URI
headers = {"Content-Type": "application/json"}
response = requests.post(scoring_uri, data=json.dumps(input_data), headers=headers)

# Get predictions
predictions = response.json()
print(predictions)