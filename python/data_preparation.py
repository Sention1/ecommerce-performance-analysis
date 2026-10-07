import os
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv


load_dotenv()

engine = create_engine(
    f"postgresql+psycopg2://"
    f"{os.getenv('DB_USER')}:"
    f"{os.getenv('DB_PASSWORD')}@"
    f"{os.getenv('DB_HOST')}:"
    f"{os.getenv('DB_PORT')}/"
    f"{os.getenv('DB_NAME')}"
)


# -------------------------
# Load raw datasets
# -------------------------

customers = pd.read_csv("data/olist_customers_dataset.csv")
orders = pd.read_csv("data/olist_orders_dataset.csv")
items = pd.read_csv("data/olist_order_items_dataset.csv")
reviews = pd.read_csv("data/olist_order_reviews_dataset.csv")
payments = pd.read_csv("data/olist_order_payments_dataset.csv")
products = pd.read_csv("data/olist_products_dataset.csv")
sellers = pd.read_csv("data/olist_sellers_dataset.csv")
location = pd.read_csv("data/olist_geolocation_dataset.csv")


# -------------------------
# Basic validation
# -------------------------

tables = {
    "customers": customers,
    "orders": orders,
    "items": items,
    "reviews": reviews,
    "payments": payments,
    "products": products,
    "sellers": sellers
}

for name, df in tables.items():
    print(f"\n--- {name} ---")
    print("Rows:", len(df))
    print("Duplicate rows:", df.duplicated().sum())
    print("Null values:")
    print(df.isnull().sum())


print("\nPrimary key checks")
print("Customer ID duplicates:", customers["customer_id"].duplicated().sum())
print("Order ID duplicates:", orders["order_id"].duplicated().sum())
print("Product ID duplicates:", products["product_id"].duplicated().sum())
print("Seller ID duplicates:", sellers["seller_id"].duplicated().sum())


# -------------------------
# Relationship validation
# -------------------------

print("\nOrders without items:",
      (~orders["order_id"].isin(items["order_id"])).sum())

print("Orders without payments:",
      (~orders["order_id"].isin(payments["order_id"])).sum())

print("Orders without reviews:",
      (~orders["order_id"].isin(reviews["order_id"])).sum())


for name, df in {
    "items": items,
    "payments": payments,
    "reviews": reviews
}.items():

    counts = df.groupby("order_id").size()

    print(f"\n--- {name} ---")
    print("Average rows per order:", counts.mean())
    print("Maximum rows per order:", counts.max())
    print("Orders with more than 1 row:", (counts > 1).sum())


# -------------------------
# Aggregate child tables
# -------------------------

items_order_level = (
    items
    .groupby("order_id")
    .agg(
        item_count=("order_item_id", "count"),
        total_item_value=("price", "sum"),
        total_freight=("freight_value", "sum")
    )
    .reset_index()
)


payments_order_level = (
    payments
    .groupby("order_id")
    .agg(
        payment_count=("payment_sequential", "count"),
        total_payment=("payment_value", "sum"),
        max_installments=("payment_installments", "max")
    )
    .reset_index()
)


reviews_order_level = (
    reviews
    .groupby("order_id")
    .agg(
        avg_review_score=("review_score", "mean"),
        review_count=("review_id", "count"),
        written_comment_count=("review_comment_message", "count")
    )
    .reset_index()
)


# -------------------------
# Build order-level table
# Grain: one row per order
# -------------------------

orders_master = (
    orders
    .merge(items_order_level, on="order_id", how="left")
    .merge(payments_order_level, on="order_id", how="left")
    .merge(customers, on="customer_id", how="left")
    .merge(reviews_order_level, on="order_id", how="left")
)


# -------------------------
# Build item-level table
# Grain: one row per order item
# -------------------------

items_fact = (
    items
    .merge(products, on="product_id", how="left")
    .merge(sellers, on="seller_id", how="left")
)


# -------------------------
# Convert date columns
# -------------------------

date_cols_orders = [
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date"
]

for col in date_cols_orders:
    orders_master[col] = pd.to_datetime(
        orders_master[col],
        errors="coerce"
    )


items_fact["shipping_limit_date"] = pd.to_datetime(
    items_fact["shipping_limit_date"],
    errors="coerce"
)


# -------------------------
# Final validation
# -------------------------

print("\nFinal table validation")

print("orders_master rows:", len(orders_master))
print(
    "orders_master unique orders:",
    orders_master["order_id"].nunique()
)

print("items_fact rows:", len(items_fact))
print(
    "items_fact unique orders:",
    items_fact["order_id"].nunique()
)

print(
    "orders_master revenue:",
    orders_master["total_item_value"].sum()
)

print(
    "items_fact revenue:",
    items_fact["price"].sum()
)


# -------------------------
# Load into PostgreSQL
# -------------------------

orders_master.to_sql(
    "orders_master",
    engine,
    if_exists="replace",
    index=False
)

items_fact.to_sql(
    "items_fact",
    engine,
    if_exists="replace",
    index=False
)

print("\nData successfully loaded into PostgreSQL.")