WITH seller_performance AS (
  SELECT 
    s.seller_id,
    s.seller_city,
    s.seller_state,
    
    COUNT(DISTINCT oi.order_id) as total_orders,
    SUM(oi.price) as total_revenue,
    AVG(oi.price) as avg_order_value,
    COUNT(DISTINCT DATE_TRUNC('month', o.order_purchase_timestamp)) as active_months,
    
  
    DATE_PART('day', '2018-09-01'::DATE - MAX(o.order_purchase_timestamp)) as recency_days,
    COUNT(DISTINCT oi.order_id) as frequency,
    SUM(oi.price) as monetary,
    
    
    COUNT(DISTINCT CASE 
      WHEN o.order_purchase_timestamp >= '2018-06-01' 
      THEN oi.order_id 
    END) as last_3_month_orders,
    COUNT(DISTINCT CASE 
      WHEN o.order_purchase_timestamp < '2018-06-01' 
      THEN oi.order_id 
    END) as previous_orders
    
  FROM olist_sellers s
  LEFT JOIN olist_order_items oi ON s.seller_id = oi.seller_id
  LEFT JOIN olist_orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY s.seller_id, s.seller_city, s.seller_state
),
rfm_scores AS (
  SELECT 
    seller_id,
    seller_city,
    seller_state,
    total_orders,
    total_revenue,
    avg_order_value,
    active_months,
    
   
    NTILE(5) OVER (ORDER BY recency_days DESC) as r_score,
    NTILE(5) OVER (ORDER BY frequency) as f_score,
    NTILE(5) OVER (ORDER BY monetary) as m_score,
    
  
    CASE 
      WHEN previous_orders = 0 THEN 1.0
      ELSE last_3_month_orders::FLOAT / previous_orders
    END as growth_rate
    
  FROM seller_performance
)
SELECT 
  seller_id,
  seller_state,
  total_orders,
  total_revenue,
  ROUND(total_revenue / NULLIF(total_orders, 0), 2) as avg_revenue_per_order,
  active_months,
  r_score + f_score + m_score as rfm_total_score,
  growth_rate,
  

  CASE 
    WHEN r_score + f_score + m_score >= 12 THEN '头部卖家'
    WHEN r_score + f_score + m_score >= 8 THEN '腰部卖家'
    ELSE '尾部卖家'
  END as seller_tier,
  

  CASE 
    WHEN growth_rate > 1.5 AND total_orders < 50 THEN '高成长潜力'
    WHEN growth_rate > 1.2 AND rfm_total_score >= 8 THEN '稳定成长'
    ELSE '需关注'
  END as growth_potential
  
FROM rfm_scores
ORDER BY total_revenue DESC
LIMIT 20;
