-- 分析1：月度整体趋势（平台视角）
WITH monthly_platform_metrics AS (
  SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) as year_month,
    -- 核心指标
    COUNT(DISTINCT s.seller_id) as active_sellers,
    COUNT(DISTINCT oi.order_id) as order_count,
    COUNT(DISTINCT o.customer_id) as customer_count,
    SUM(oi.price) as gmv,
    AVG(oi.price) as avg_order_value,
    -- 卖家质量指标
    COUNT(DISTINCT CASE WHEN oi.price > 100 THEN s.seller_id END) as premium_sellers,
    COUNT(DISTINCT CASE WHEN DATE_TRUNC('month', o.order_purchase_timestamp) = 
      DATE_TRUNC('month', s2.first_order_date) THEN s.seller_id END) as new_sellers
    
  FROM olist_orders o
  JOIN olist_order_items oi ON o.order_id = oi.order_id
  JOIN olist_sellers s ON oi.seller_id = s.seller_id
  LEFT JOIN (
    SELECT seller_id, MIN(order_purchase_timestamp) as first_order_date
    FROM olist_order_items oi2
    JOIN olist_orders o2 ON oi2.order_id = o2.order_id
    WHERE o2.order_status = 'delivered'
    GROUP BY seller_id
  ) s2 ON s.seller_id = s2.seller_id
  
  WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2018-09-01'
    
  GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
),
monthly_growth AS (
  SELECT 
    TO_CHAR(year_month, 'YYYY-MM') as year_month,
    active_sellers,
    order_count,
    customer_count,
    ROUND(gmv, 2) as gmv,
    ROUND(avg_order_value, 2) as avg_order_value,
    premium_sellers,
    new_sellers,
    -- 环比计算
    ROUND(
      (gmv - LAG(gmv, 1) OVER (ORDER BY year_month)) * 100.0 /
      NULLIF(LAG(gmv, 1) OVER (ORDER BY year_month), 0),
      2
    ) as gmv_growth_rate,
    
    ROUND(
      (active_sellers - LAG(active_sellers, 1) OVER (ORDER BY year_month)) * 100.0 /
      NULLIF(LAG(active_sellers, 1) OVER (ORDER BY year_month), 0),
      2
    ) as seller_growth_rate,
    
    -- 卖家质量占比
    ROUND(premium_sellers * 100.0 / NULLIF(active_sellers, 0), 2) as premium_seller_ratio,
    ROUND(new_sellers * 100.0 / NULLIF(active_sellers, 0), 2) as new_seller_ratio
    
  FROM monthly_platform_metrics
)
SELECT 
  year_month,
  active_sellers,
  order_count,
  ROUND(gmv, 2) as gmv,
  gmv_growth_rate || '%' as gmv_growth,
  seller_growth_rate || '%' as seller_growth,
  premium_seller_ratio || '%' as premium_ratio,
  new_seller_ratio || '%' as new_seller_ratio,
  
  -- 趋势判断
  CASE 
    WHEN gmv_growth_rate > 20 THEN '高速增长'
    WHEN gmv_growth_rate > 5 THEN '稳定增长'
    WHEN gmv_growth_rate < -5 THEN '增长放缓'
    WHEN gmv_growth_rate IS NULL THEN '首月数据'
    ELSE '平稳运营'
  END as growth_status
  
FROM monthly_growth
ORDER BY year_month DESC;

-- 分析2：卖家生命周期分析
WITH seller_monthly_activity AS (
  SELECT 
    s.seller_id,
    s.seller_state,
    DATE_TRUNC('month', o.order_purchase_timestamp) as activity_month,
    COUNT(DISTINCT oi.order_id) as monthly_orders,
    SUM(oi.price) as monthly_revenue,
    COUNT(DISTINCT oi.product_id) as unique_products
    
  FROM olist_sellers s
  JOIN olist_order_items oi ON s.seller_id = oi.seller_id
  JOIN olist_orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY s.seller_id, s.seller_state, DATE_TRUNC('month', o.order_purchase_timestamp)
),
seller_first_month AS (
  SELECT 
    seller_id,
    MIN(activity_month) as first_active_month
  FROM seller_monthly_activity
  GROUP BY seller_id
),
seller_lifecycle AS (
  SELECT 
    sma.seller_id,
    sma.seller_state,
    sma.activity_month,
    EXTRACT(MONTH FROM AGE(sma.activity_month, sfm.first_active_month)) as months_since_start,
    sma.monthly_orders,
    sma.monthly_revenue,
    sma.unique_products,
    -- 计算环比
    LAG(sma.monthly_revenue, 1) OVER (PARTITION BY sma.seller_id ORDER BY sma.activity_month) as prev_month_revenue,
    LAG(sma.monthly_orders, 1) OVER (PARTITION BY sma.seller_id ORDER BY sma.activity_month) as prev_month_orders
    
  FROM seller_monthly_activity sma
  JOIN seller_first_month sfm ON sma.seller_id = sfm.seller_id
)
SELECT 
  months_since_start,
  COUNT(DISTINCT seller_id) as active_sellers,
  ROUND(AVG(monthly_orders), 2) as avg_monthly_orders,
  ROUND(AVG(monthly_revenue), 2) as avg_monthly_revenue,
  ROUND(AVG(unique_products), 2) as avg_unique_products,
  
  -- 留存率计算
  ROUND(
    COUNT(DISTINCT seller_id) * 100.0 / 
    FIRST_VALUE(COUNT(DISTINCT seller_id)) OVER (ORDER BY months_since_start),
    2
  ) as retention_rate,
  
  -- 成长率
  ROUND(
    AVG(
      CASE 
        WHEN prev_month_revenue > 0 
        THEN (monthly_revenue - prev_month_revenue) * 100.0 / prev_month_revenue
        ELSE NULL
      END
    ), 2
  ) as avg_growth_rate,
  
  -- 成长阶段分类
  CASE 
    WHEN months_since_start = 0 THEN '引入期'
    WHEN months_since_start <= 3 THEN '成长期'
    WHEN months_since_start <= 12 THEN '成熟期'
    ELSE '稳定期'
  END as lifecycle_stage
  
FROM seller_lifecycle
WHERE months_since_start <= 18  
GROUP BY months_since_start
ORDER BY months_since_start;

-- 分析3：高成长卖家识别
WITH seller_monthly_stats AS (
  SELECT 
    s.seller_id,
    s.seller_state,
    DATE_TRUNC('month', o.order_purchase_timestamp) as sales_month,
    SUM(oi.price) as monthly_revenue,
    COUNT(DISTINCT oi.order_id) as monthly_orders
    
  FROM olist_sellers s
  JOIN olist_order_items oi ON s.seller_id = oi.seller_id
  JOIN olist_orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2018-01-01'
  GROUP BY s.seller_id, s.seller_state, DATE_TRUNC('month', o.order_purchase_timestamp)
),
seller_growth_metrics AS (
  SELECT 
    seller_id,
    seller_state,
    sales_month,
    monthly_revenue,
    monthly_orders,
    LAG(monthly_revenue, 1) OVER (PARTITION BY seller_id ORDER BY sales_month) as prev_month_revenue,
    LAG(monthly_orders, 1) OVER (PARTITION BY seller_id ORDER BY sales_month) as prev_month_orders,
    
    -- 三个月移动平均
    AVG(monthly_revenue) OVER (
      PARTITION BY seller_id 
      ORDER BY sales_month 
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as ma3_revenue
    
  FROM seller_monthly_stats
)
SELECT 
  seller_id,
  seller_state,
  TO_CHAR(MAX(sales_month), 'YYYY-MM') as last_active_month,
  COUNT(DISTINCT sales_month) as active_months,
  ROUND(SUM(monthly_revenue), 2) as total_revenue,
  ROUND(AVG(monthly_revenue), 2) as avg_monthly_revenue,
  MAX(monthly_revenue) as peak_monthly_revenue,
  
  -- 增长指标
  ROUND(
    AVG(
      CASE 
        WHEN prev_month_revenue > 0 
        THEN (monthly_revenue - prev_month_revenue) * 100.0 / prev_month_revenue
        ELSE NULL
      END
    ), 2
  ) as avg_monthly_growth_rate,
  
  -- 稳定性指标
  ROUND(
    STDDEV(monthly_revenue) / NULLIF(AVG(monthly_revenue), 0),
    2
  ) as revenue_volatility,
  
  -- 成长类型判断
  CASE 
    WHEN COUNT(DISTINCT sales_month) = 1 THEN '新晋卖家'
    WHEN AVG(
      CASE 
        WHEN prev_month_revenue > 0 
        THEN (monthly_revenue - prev_month_revenue) * 100.0 / prev_month_revenue
        ELSE NULL
      END
    ) > 30 THEN '高速成长卖家'
    WHEN AVG(monthly_revenue) > 500 AND COUNT(DISTINCT sales_month) >= 3 THEN '稳定高产卖家'
    WHEN MAX(monthly_revenue) > 1000 THEN '潜力爆款卖家'
    ELSE '平稳运营卖家'
  END as growth_type,
  
  -- 运营建议
  CASE 
    WHEN COUNT(DISTINCT sales_month) = 1 THEN '提供新手引导'
    WHEN AVG(
      CASE 
        WHEN prev_month_revenue > 0 
        THEN (monthly_revenue - prev_month_revenue) * 100.0 / prev_month_revenue
        ELSE NULL
      END
    ) > 30 THEN '加大流量扶持'
    WHEN AVG(monthly_revenue) > 500 AND COUNT(DISTINCT sales_month) >= 3 THEN '深化合作'
    WHEN MAX(monthly_revenue) > 1000 THEN '分析爆款及复刻'
    ELSE '常规运营支持'
  END as growth_suggestion
  
FROM seller_growth_metrics
WHERE monthly_revenue > 0
GROUP BY seller_id, seller_state
HAVING COUNT(DISTINCT sales_month) >= 2 
ORDER BY avg_monthly_growth_rate DESC, total_revenue DESC
LIMIT 20;
