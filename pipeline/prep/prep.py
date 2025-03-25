import pandas as pd
from sklearn.model_selection import train_test_split

# Load the dataset
df = pd.read_csv("globojava_sales_data_with_quantity.csv")

# Aggregate data at the monthly level
df["Date"] = pd.to_datetime(df["Date"])
df["MonthYear"] = df["Date"].dt.to_period("M")
monthly_data = df.groupby(["StoreID", "Country", "City", "MonthYear"]).agg({
    "QuantitySold": "sum",
    "Price": "mean",
    "Weather": "last",  # Use the last recorded weather for the month
    "Promotion": "last",  # Use the last recorded promotion for the month
    "Holiday": "last"  # Use the last recorded holiday for the month
}).reset_index()

# Split the data into 80% training and 20% testing
train_data, test_data = train_test_split(monthly_data, test_size=0.2, random_state=42)

# Save the split data
train_data.to_csv("train_data_monthly.csv", index=False)
test_data.to_csv("test_data_monthly.csv", index=False)