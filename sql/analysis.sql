-- =========================================================
-- Olist E-commerce Performance Analysis
-- PostgreSQL
-- =========================================================


-- =========================================================
-- 1. Table validation
-- =========================================================

    SELECT
        COUNT(*) AS total_rows,
        COUNT(DISTINCT order_id) AS unique_orders
    FROM orders_master;


    SELECT
        COUNT(*) AS total_rows,
        COUNT(DISTINCT order_id) AS unique_orders
    FROM items_fact;



-- =========================================================
-- 2. Revenue and orders by customer state
-- =========================================================

    SELECT
    om.customer_state,
        SUM(i.price) AS total_revenue,
        COUNT(DISTINCT om.order_id) AS num_of_orders
    FROM orders_master om
    JOIN items_fact i
        ON om.order_id = i.order_id
    GROUP BY om.customer_state
    ORDER BY total_revenue DESC;



-- =========================================================
-- 3. Top 10 product categories by revenue
-- =========================================================

    SELECT
        product_category_name,
        SUM(price) AS total_item_revenue
    FROM items_fact
    GROUP BY product_category_name
    ORDER BY total_item_revenue DESC
    LIMIT 10;



-- =========================================================
-- 4. Average review score by customer state
-- =========================================================

    SELECT
        customer_state,
        AVG(avg_review_score) AS avg_review
    FROM orders_master
    GROUP BY customer_state
    ORDER BY avg_review DESC;



-- =========================================================
-- 5. Average freight value by product category
-- =========================================================

    SELECT
        product_category_name,
        AVG(freight_value) AS avg_freight_value
    FROM items_fact
    GROUP BY product_category_name
    ORDER BY avg_freight_value DESC;



-- =========================================================
-- 6. Monthly order volume and payment value
-- =========================================================

    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS month,
        COUNT(order_id) AS num_of_orders,
        SUM(total_payment) AS total_payment
    FROM orders_master
    GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
    ORDER BY month;



-- =========================================================
-- 7. Top states by average order value
-- =========================================================

    SELECT
        customer_state,
        COUNT(order_id) AS num_of_orders,
        SUM(total_item_value) AS total_revenue,
        AVG(total_item_value) AS avg_order_value
    FROM orders_master
    GROUP BY customer_state
    ORDER BY avg_order_value DESC
    LIMIT 10;



-- =========================================================
-- 8. Top 10 sellers by revenue
-- =========================================================

    SELECT
        seller_id,
        SUM(price) AS total_revenue,
        COUNT(order_item_id) AS num_of_items_sold,
        COUNT(DISTINCT order_id) AS num_of_distinct_orders
    FROM items_fact
    GROUP BY seller_id
    ORDER BY total_revenue DESC
    LIMIT 10;



-- =========================================================
-- 9. Month-over-month revenue growth
-- =========================================================

    WITH monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', order_purchase_timestamp) AS month,
            SUM(total_item_value) AS total_revenue
        FROM orders_master
        GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
),

    revenue_with_previous_month AS (
        SELECT
            month,
            total_revenue,
            LAG(total_revenue) OVER (
                ORDER BY month
            ) AS previous_month_revenue
        FROM monthly_revenue
)

    SELECT
        month,
        total_revenue,
        previous_month_revenue,
        ROUND(
            (
                (
                    total_revenue - previous_month_revenue
                )
                / NULLIF(previous_month_revenue, 0)
                * 100
            )::numeric,
            2
        ) AS growth_pct
    FROM revenue_with_previous_month
    ORDER BY month;



-- =========================================================
-- 10. Repeat customers
-- =========================================================

    SELECT
        customer_unique_id,
        COUNT(order_id) AS num_of_orders,
        SUM(total_item_value) AS total_spent
    FROM orders_master
    GROUP BY customer_unique_id
    HAVING COUNT(order_id) > 1
    ORDER BY total_spent DESC;



-- =========================================================
-- 11. Top 3 product categories within each customer state
-- =========================================================

WITH category_revenue AS (
        SELECT
            om.customer_state,
            i.product_category_name,
            SUM(i.price) AS category_revenue,
            DENSE_RANK() OVER (
                PARTITION BY om.customer_state
                ORDER BY SUM(i.price) DESC
            ) AS category_rank
        FROM orders_master om
        JOIN items_fact i
            ON om.order_id = i.order_id
        GROUP BY
            om.customer_state,
            i.product_category_name
)

    SELECT
        customer_state,
        product_category_name,
        category_revenue,
        category_rank
    FROM category_revenue
    WHERE category_rank <= 3
    ORDER BY
        customer_state,
        category_rank;



-- =========================================================
-- 12. Late delivery rate by customer state
-- =========================================================

    WITH delivery_stats AS (
        SELECT
            customer_state,
            COUNT(order_delivered_customer_date) AS orders_delivered,
            SUM(
                CASE
                    WHEN order_delivered_customer_date >
                        order_estimated_delivery_date
                    THEN 1
                    ELSE 0
                END
            ) AS late_orders
        FROM orders_master
        GROUP BY customer_state
)

    SELECT
        customer_state,
        orders_delivered,
        late_orders,
        ROUND(
            (
                late_orders * 100.0
                / NULLIF(orders_delivered, 0)
            )::numeric,
            2
        ) AS late_pct
    FROM delivery_stats
    ORDER BY late_pct DESC;



-- =========================================================
-- 13. Average number of late days by state
-- =========================================================

    SELECT
        customer_state,
        AVG(
            EXTRACT(
                DAY FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            )
        ) AS avg_num_of_late_days
    FROM orders_master
    WHERE
        order_delivered_customer_date >
        order_estimated_delivery_date
    GROUP BY customer_state
    ORDER BY avg_num_of_late_days DESC;



-- =========================================================
-- 14. Seller performance
-- =========================================================

    SELECT
        seller_id,
        SUM(price) AS total_revenue,
        COUNT(DISTINCT order_id) AS num_of_distinct_orders,
        AVG(price) AS avg_item_price,
        AVG(freight_value) AS avg_freight_value
    FROM items_fact
    GROUP BY seller_id
    ORDER BY total_revenue DESC;



-- =========================================================
-- 15. Revenue validation across table grains
-- =========================================================

    SELECT
        (
            SELECT SUM(total_item_value)
            FROM orders_master
        ) AS total_revenue_orders,

        (
            SELECT SUM(price)
            FROM items_fact
        ) AS total_revenue_items;