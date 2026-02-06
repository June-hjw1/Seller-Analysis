-- 第一部分：RFM基础分析
WITH seller_rfm_base AS (
  SELECT 
    s.seller_id,
    s.seller_state,
    -- Recency: 最近购买时间
    COALESCE(DATE_PART('day', TIMESTAMP '2018-10-01' - MAX(o.order_purchase_timestamp)), 365) as recency_days,
    -- Frequency: 订单频率
    COUNT(DISTINCT oi.order_id) as frequency,
    -- Monetary: 消费金额
    COALESCE(SUM(oi.price), 0) as monetary,
    -- 附加指标
    COUNT(DISTINCT o.customer_id) as customer_count,
    COALESCE(AVG(oi.price), 0) as avg_order_value,
    COUNT(DISTINCT oi.product_id) as unique_products
    
  FROM olist_sellers s
  LEFT JOIN olist_order_items oi ON s.seller_id = oi.seller_id
  LEFT JOIN olist_orders o ON oi.order_id = o.order_id AND o.order_status = 'delivered'
  GROUP BY s.seller_id, s.seller_state
),
-- 第二部分：RFM打分
rfm_scoring AS (
  SELECT 
    *,
    -- 5分制打分
    CASE 
      WHEN frequency = 0 THEN 1  
      ELSE NTILE(5) OVER (ORDER BY recency_days DESC) 
    END as recency_score,
    
    CASE 
      WHEN frequency = 0 THEN 1
      ELSE NTILE(5) OVER (ORDER BY frequency) 
    END as frequency_score,
    
    CASE 
      WHEN monetary = 0 THEN 1
      ELSE NTILE(5) OVER (ORDER BY monetary) 
    END as monetary_score
    
  FROM seller_rfm_base
),
-- 第三部分：计算总分和分层
rfm_tiering AS (
  SELECT 
    seller_id,
    seller_state,
    recency_days,
    frequency,
    monetary,
    customer_count,
    avg_order_value,
    unique_products,
    recency_score,
    frequency_score,
    monetary_score,
    recency_score + frequency_score + monetary_score as rfm_total_score,
    
    -- 业务分层
    CASE 
      WHEN frequency = 0 THEN '待激活卖家'
      WHEN recency_score + frequency_score + monetary_score >= 12 THEN '头部卖家'
      WHEN recency_score + frequency_score + monetary_score >= 8 THEN '成长卖家'
      WHEN recency_score + frequency_score + monetary_score >= 5 THEN '活跃卖家'
      ELSE '观察卖家'
    END as seller_tier,
    
    -- 建议
    CASE 
      WHEN frequency = 0 THEN '需激活：引导完成首单'
      WHEN recency_score <= 2 AND frequency_score >= 4 THEN '重点维护：高复购但近期沉默'
      WHEN monetary_score >= 4 AND frequency_score <= 2 THEN '提升频次：高客单低频购买'
      WHEN recency_score >= 4 AND monetary_score >= 3 THEN '流失风险：高价值但近期未购'
      ELSE '健康运营'
    END as operation_suggestion
    
  FROM rfm_scoring
)
-- 第四部分：输出
SELECT 
  seller_id,
  seller_state,
  frequency as order_count,
  ROUND(monetary, 2) as total_revenue,
  customer_count,
  ROUND(avg_order_value, 2) as avg_order_value,
  recency_score,
  frequency_score,
  monetary_score,
  rfm_total_score,
  seller_tier,
  operation_suggestion,
  -- 优先级标记
  CASE 
    WHEN seller_tier = '待激活卖家' THEN '高优先级'
    WHEN seller_tier = '头部卖家' THEN '核心维护'
    WHEN seller_tier = '成长卖家' THEN '重点扶持'
    WHEN operation_suggestion LIKE '%流失风险%' THEN '预警关注'
    ELSE '常规运营'
  END as priority_level
  
FROM rfm_tiering
WHERE frequency > 0  -- 只展示有交易的卖家
ORDER BY monetary DESC, frequency DESC
LIMIT 25;

-- 第五部分：分层统计汇总
SELECT 
  seller_tier,
  COUNT(*) as seller_count,
  ROUND(AVG(frequency), 2) as avg_orders,
  ROUND(SUM(monetary), 2) as total_revenue,
  ROUND(AVG(monetary), 2) as avg_revenue,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as seller_percentage,
  ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER(), 2) as revenue_percentage
FROM (
  SELECT 
    seller_id,
    frequency,
    monetary,
    CASE 
      WHEN frequency = 0 THEN '待激活卖家'
      WHEN recency_score + frequency_score + monetary_score >= 12 THEN '头部卖家'
      WHEN recency_score + frequency_score + monetary_score >= 8 THEN '成长卖家'
      WHEN recency_score + frequency_score + monetary_score >= 5 THEN '活跃卖家'
      ELSE '观察卖家'
    END as seller_tier
  FROM rfm_scoring
) tiered
GROUP BY seller_tier
ORDER BY 
  CASE seller_tier
    WHEN '头部卖家' THEN 1
    WHEN '成长卖家' THEN 2
    WHEN '活跃卖家' THEN 3
    WHEN '观察卖家' THEN 4
    WHEN '待激活卖家' THEN 5
  END;
