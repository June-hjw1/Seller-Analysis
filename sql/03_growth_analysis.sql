WITH monthly_sales AS (
  SELECT 
    s.seller_id,
    s.seller_state,
    DATE_TRUNC('month', o.order_purchase_timestamp) as sales_month,
    COUNT(DISTINCT oi.order_id) as monthly_orders,
    SUM(oi.price) as monthly_revenue,
    COUNT(DISTINCT oi.product_id) as unique_products
    
  FROM olist_sellers s
  JOIN olist_order_items oi ON s.seller_id = oi.seller_id
  JOIN olist_orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
  GROUP BY s.seller_id, s.seller_state, DATE_TRUNC('month', o.order_purchase_timestamp)
),
seller_first_month AS (
  SELECT 
    seller_id,
    MIN(sales_month) as first_sale_month
  FROM monthly_sales
  GROUP BY seller_id
),
monthly_growth AS (
  SELECT 
    ms.seller_id,
    ms.seller_state,
    ms.sales_month,
    ms.monthly_orders,
    ms.monthly_revenue,
    LAG(ms.monthly_revenue, 1) OVER (PARTITION BY ms.seller_id ORDER BY ms.sales_month) as prev_month_revenue,
    LAG(ms.monthly_orders, 1) OVER (PARTITION BY ms.seller_id ORDER BY ms.sales_month) as prev_month_orders,
    EXTRACT('month' FROM AGE(ms.sales_month, sfm.first_sale_month)) as months_since_start
    
  FROM monthly_sales ms
  JOIN seller_first_month sfm ON ms.seller_id = sfm.seller_id
)
SELECT 
  sales_month,
  seller_state,
  COUNT(DISTINCT seller_id) as active_sellers,
  SUM(monthly_revenue) as total_monthly_revenue,
  AVG(monthly_revenue) as avg_seller_revenue,
 
  ROUND(
    (SUM(monthly_revenue) - LAG(SUM(monthly_revenue), 1) OVER (ORDER BY sales_month)) * 100.0 / 
    NULLIF(LAG(SUM(monthly_revenue), 1) OVER (ORDER BY sales_month), 0),
    2
  ) as monthly_growth_rate,
 
  ROUND(
    SUM(CASE WHEN months_since_start = 0 THEN 1 ELSE 0 END) * 100.0 / 
    NULLIF(COUNT(DISTINCT seller_id), 0),
    2
  ) as new_seller_percentage
  
FROM monthly_growth
GROUP BY sales_month, seller_state
ORDER BY sales_month DESC, total_monthly_revenue DESC;
