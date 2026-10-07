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



query = """
SELECT
    seller_id,
    SUM(price) AS total_revenue,
    COUNT(DISTINCT order_id) AS num_of_distinct_orders,
    AVG(price) AS avg_item_price,
    AVG(freight_value) AS avg_freight_value
FROM items_fact
GROUP BY seller_id
ORDER BY total_revenue DESC;
"""

seller_performance = pd.read_sql(query, engine)

print(seller_performance.head())




seller_performance.to_excel(
    "seller_performance.xlsx",
    index=False
)



