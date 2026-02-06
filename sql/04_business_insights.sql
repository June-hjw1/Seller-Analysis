-- 洞察1：地域分布与绩效关系
SELECT 
  seller_state,
  COUNT(DISTINCT s.seller_id) as seller_count,
  COUNT(DISTINCT oi.order_id) as order_count,
  ROUND(SUM(oi.price), 2) as total_revenue,
  ROUND(AVG(oi.price), 2) as avg_order_value,
  ROUND(SUM(oi.price) / NULLIF(COUNT(DISTINCT s.seller_id), 0), 2) as revenue_per_seller,
  COUNT(DISTINCT o.customer_id) as customer_count,
  
  -- 市场集中度指标
  ROUND(
    COUNT(DISTINCT s.seller_id) * 100.0 / SUM(COUNT(DISTINCT s.seller_id)) OVER(),
    2
  ) as seller_market_share,
  
  ROUND(
    SUM(oi.price) * 100.0 / SUM(SUM(oi.price)) OVER(),
    2
  ) as revenue_market_share,
  
  -- 市场饱和度
  ROUND(
    COUNT(DISTINCT o.customer_id) * 1.0 / NULLIF(COUNT(DISTINCT s.seller_id), 0),
    2
  ) as customers_per_seller,
  
  -- 市场机会评估
  CASE 
    WHEN COUNT(DISTINCT s.seller_id) < 10 AND SUM(oi.price) > 5000 THEN '高潜力市场'
    WHEN revenue_market_share > 20 AND seller_market_share < 15 THEN '高效集约市场'
    WHEN customers_per_seller > 50 THEN '买家密集市场'
    WHEN COUNT(DISTINCT s.seller_id) > 50 AND revenue_per_seller < 100 THEN '高度竞争市场'
    ELSE '均衡发展市场'
  END as market_characteristics,
  
  -- 地域策略建议
  CASE 
    WHEN COUNT(DISTINCT s.seller_id) < 10 AND SUM(oi.price) > 5000 THEN 
      '加大卖家招募，抢占市场先机'
    WHEN revenue_market_share > 20 AND seller_market_share < 15 THEN 
      '扶持头部卖家，提升市场效率'
    WHEN customers_per_seller > 50 THEN 
      '引入更多卖家，满足买家需求'
    WHEN COUNT(DISTINCT s.seller_id) > 50 AND revenue_per_seller < 100 THEN 
      '优化卖家结构，淘汰低效卖家'
    ELSE '保持现有策略，稳步发展'
  END as regional_strategy
  
FROM olist_sellers s
LEFT JOIN olist_order_items oi ON s.seller_id = oi.seller_id
LEFT JOIN olist_orders o ON oi.order_id = o.order_id AND o.order_status = 'delivered'
GROUP BY seller_state
HAVING COUNT(DISTINCT oi.order_id) > 5 
ORDER BY total_revenue DESC;

-- 洞察2：卖家生命周期价值分析
WITH seller_lifetime_value AS (
  SELECT 
    s.seller_id,
    s.seller_state,
    -- 生命周期价值指标
    MIN(o.order_purchase_timestamp) as first_order_date,
    MAX(o.order_purchase_timestamp) as last_order_date,
    COUNT(DISTINCT oi.order_id) as lifetime_orders,
    SUM(oi.price) as lifetime_revenue,
    COUNT(DISTINCT o.customer_id) as lifetime_customers,
    COUNT(DISTINCT oi.product_id) as lifetime_products,
    
    -- 活跃天数
    DATE_PART('day', MAX(o.order_purchase_timestamp) - MIN(o.order_purchase_timestamp)) as active_days,
    
    -- 购买间隔
    ROUND(
      DATE_PART('day', MAX(o.order_purchase_timestamp) - MIN(o.order_purchase_timestamp)) / 
      NULLIF(COUNT(DISTINCT oi.order_id), 0),
      2
    ) as avg_order_interval_days
    
  FROM olist_sellers s
  JOIN olist_order_items oi ON s.seller_id = oi.seller_id
  JOIN olist_orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY s.seller_id, s.seller_state
),
ltv_segmentation AS (
  SELECT 
    seller_id,
    seller_state,
    lifetime_orders,
    ROUND(lifetime_revenue, 2) as lifetime_revenue,
    lifetime_customers,
    lifetime_products,
    active_days,
    avg_order_interval_days,
    
    -- LTV分层
    CASE 
      WHEN lifetime_revenue >= 5000 THEN '高价值卖家'
      WHEN lifetime_revenue >= 1000 THEN '中高价值卖家'
      WHEN lifetime_revenue >= 200 THEN '中等价值卖家'
      WHEN lifetime_revenue > 0 THEN '低价值卖家'
      ELSE '无价值卖家'
    END as ltv_segment,
    
    -- 忠诚度分层
    CASE 
      WHEN lifetime_orders >= 20 THEN '高忠诚度'
      WHEN lifetime_orders >= 10 THEN '中忠诚度'
      WHEN lifetime_orders >= 3 THEN '低忠诚度'
      WHEN lifetime_orders > 0 THEN '尝鲜型'
      ELSE '未激活'
    END as loyalty_segment,
    
    -- 健康度评估
    CASE 
      WHEN active_days > 180 AND avg_order_interval_days < 30 THEN '健康活跃'
      WHEN active_days > 90 AND lifetime_orders >= 5 THEN '稳定运营'
      WHEN active_days <= 30 AND lifetime_orders >= 3 THEN '快速启动'
      WHEN active_days > 180 AND lifetime_orders <= 3 THEN '低活跃度'
      WHEN active_days <= 90 AND lifetime_orders <= 2 THEN '新卖家'
      ELSE '发展中期'
    END as health_status
    
  FROM seller_lifetime_value
)
SELECT 
  ltv_segment,
  loyalty_segment,
  health_status,
  COUNT(*) as seller_count,
  ROUND(AVG(lifetime_revenue), 2) as avg_lifetime_value,
  ROUND(AVG(lifetime_orders), 2) as avg_lifetime_orders,
  ROUND(AVG(active_days), 2) as avg_active_days,
  
  -- 价值密度
  ROUND(AVG(lifetime_revenue) / NULLIF(AVG(active_days), 0), 2) as daily_value_density,
  
  -- 策略建议
  CASE 
    WHEN ltv_segment = '高价值卖家' AND loyalty_segment = '高忠诚度' THEN 
      '核心合作伙伴，提供VIP服务'
    WHEN ltv_segment = '中高价值卖家' AND health_status = '健康活跃' THEN 
      '重点培养对象，提供增长资源'
    WHEN ltv_segment IN ('中等价值卖家', '低价值卖家') AND health_status = '快速启动' THEN 
      '高潜力卖家，加强引导支持'
    WHEN health_status = '低活跃度' THEN 
      '激活计划：召回激励活动'
    WHEN health_status = '新卖家' THEN 
      '新手扶持：培训+流量支持'
    ELSE '常规运营管理'
  END as retention_strategy
  
FROM ltv_segmentation
WHERE ltv_segment != '无价值卖家'
GROUP BY ltv_segment, loyalty_segment, health_status
ORDER BY 
  CASE ltv_segment
    WHEN '高价值卖家' THEN 1
    WHEN '中高价值卖家' THEN 2
    WHEN '中等价值卖家' THEN 3
    WHEN '低价值卖家' THEN 4
  END,
  seller_count DESC;

-- 洞察3：增长机会识别与优先级排序
WITH opportunity_analysis AS (
  SELECT 
    s.seller_id,
    s.seller_state,
    -- 当前状态指标
    COUNT(DISTINCT oi.order_id) as current_orders,
    SUM(oi.price) as current_revenue,
    COUNT(DISTINCT o.customer_id) as current_customers,
    
    -- 增长潜力指标
    COUNT(DISTINCT CASE 
      WHEN o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '90 days' 
      THEN oi.order_id 
    END) as recent_orders,
    
    SUM(CASE 
      WHEN o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '90 days' 
      THEN oi.price 
    END) as recent_revenue,
    
    -- 横向对比（同地域）
    ROUND(
      SUM(oi.price) * 1.0 / AVG(SUM(oi.price)) OVER (PARTITION BY s.seller_state),
      2
    ) as regional_performance_ratio,
    
    -- 增长加速度
    ROUND(
      (SUM(CASE 
        WHEN o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '90 days' 
        THEN oi.price 
      END) * 4) / NULLIF(SUM(oi.price), 0),  -- 近90天*4推算年化
      2
    ) as growth_acceleration
    
  FROM olist_sellers s
  JOIN olist_order_items oi ON s.seller_id = oi.seller_id
  JOIN olist_orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY s.seller_id, s.seller_state
)
SELECT 
  seller_id,
  seller_state,
  current_orders,
  ROUND(current_revenue, 2) as current_revenue,
  current_customers,
  recent_orders,
  ROUND(recent_revenue, 2) as recent_revenue,
  regional_performance_ratio,
  growth_acceleration,
  
  -- 机会评分（1-10分）
  ROUND(
    (CASE WHEN current_revenue > 1000 THEN 3 ELSE 1 END) +
    (CASE WHEN recent_orders > current_orders * 0.3 THEN 2 ELSE 0 END) +
    (CASE WHEN regional_performance_ratio > 1.5 THEN 2 ELSE 0 END) +
    (CASE WHEN growth_acceleration > 1.2 THEN 3 ELSE 0 END),
    0
  ) as opportunity_score,
  
  -- 机会类型
  CASE 
    WHEN growth_acceleration > 1.5 AND current_revenue > 500 THEN '高增长潜力'
    WHEN regional_performance_ratio > 2 THEN '地域标杆卖家'
    WHEN recent_orders > current_orders * 0.5 THEN '快速上升期'
    WHEN current_revenue > 2000 THEN '规模扩展机会'
    WHEN current_customers >= 10 AND current_revenue < 500 THEN '复购提升机会'
    ELSE '常规优化机会'
  END as opportunity_type,
  
  -- 具体行动建议
  CASE 
    WHEN growth_acceleration > 1.5 AND current_revenue > 500 THEN 
      '提供专属增长顾问，制定规模化方案'
    WHEN regional_performance_ratio > 2 THEN 
      '打造地域标杆案例，提供资源倾斜'
    WHEN recent_orders > current_orders * 0.5 THEN 
      '加强供应链支持，满足增长需求'
    WHEN current_revenue > 2000 THEN 
      '探讨品牌合作，拓展新品线'
    WHEN current_customers >= 10 AND current_revenue < 500 THEN 
      '开展老客复购活动，提升客单价'
    ELSE '常规运营优化指导'
  END as action_plan,
  
  -- 优先级
  CASE 
    WHEN opportunity_score >= 8 THEN 'P0-立即跟进'
    WHEN opportunity_score >= 6 THEN 'P1-本周安排'
    WHEN opportunity_score >= 4 THEN 'P2-本月计划'
    ELSE 'P3-长期观察'
  END as priority_level
  
FROM opportunity_analysis
WHERE current_orders > 0
ORDER BY opportunity_score DESC, current_revenue DESC
LIMIT 25;
