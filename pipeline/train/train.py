import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import mean_absolute_error
import joblib

# Load the training data
train_data = pd.read_csv("train_data_monthly.csv")

# Define features and target
X_train = train_data.drop(columns=["QuantitySold", "MonthYear"])
y_train = train_data["QuantitySold"]

# Preprocessing pipeline
categorical_cols = ["StoreID", "Country", "City", "Weather", "Promotion", "Holiday"]
numerical_cols = ["Price"]

preprocessor = ColumnTransformer(
    transformers=[
        ("cat", OneHotEncoder(handle_unknown="ignore"), categorical_cols),
        ("num", StandardScaler(), numerical_cols)
    ])

# Define the model
model = Pipeline(steps=[
    ("preprocessor", preprocessor),
    ("regressor", RandomForestRegressor(random_state=42))
])

# Train the model
model.fit(X_train, y_train)

# Save the model
joblib.dump(model, "model_monthly.pkl")