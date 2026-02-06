-- 1. 创建卖家表
CREATE TABLE IF NOT EXISTS olist_sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5),
    seller_city VARCHAR(50),
    seller_state VARCHAR(2)
);

-- 2. 创建订单表
CREATE TABLE IF NOT EXISTS olist_orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32),
    order_status VARCHAR(20),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- 3. 创建订单商品表（关键表）
CREATE TABLE IF NOT EXISTS olist_order_items (
    order_id VARCHAR(32),
    order_item_id INTEGER,
    product_id VARCHAR(32),
    seller_id VARCHAR(32),
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 4. 创建索引（提高查询性能）
CREATE INDEX IF NOT EXISTS idx_order_items_seller_id ON olist_order_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON olist_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_orders_purchase_time ON olist_orders(order_purchase_timestamp);
CREATE INDEX IF NOT EXISTS idx_orders_status ON olist_orders(order_status);

-- 5. 清空现有数据（如果存在）
TRUNCATE TABLE olist_order_items;
TRUNCATE TABLE olist_orders;
TRUNCATE TABLE olist_sellers;

-- 6. 从CSV导入数据
-- 注意：在Docker环境中，文件路径为 /tmp/data/
COPY olist_sellers FROM '/tmp/data/olist_sellers_dataset.csv' DELIMITER ',' CSV HEADER;
COPY olist_orders FROM '/tmp/data/olist_orders_dataset.csv' DELIMITER ',' CSV HEADER;
COPY olist_order_items FROM '/tmp/data/olist_order_items_dataset.csv' DELIMITER ',' CSV HEADER;

-- 7. 数据质量检查
DO $$
DECLARE
    seller_count INT;
    order_count INT;
    item_count INT;
BEGIN
    SELECT COUNT(*) INTO seller_count FROM olist_sellers;
    SELECT COUNT(*) INTO order_count FROM olist_orders;
    SELECT COUNT(*) INTO item_count FROM olist_order_items;
    
    RAISE NOTICE '数据导入完成！';
    RAISE NOTICE '   卖家数量: %', seller_count;
    RAISE NOTICE '   订单数量: %', order_count;
    RAISE NOTICE '   订单商品数量: %', item_count;
    
    -- 检查数据完整性
    IF seller_count > 0 AND order_count > 0 AND item_count > 0 THEN
        RAISE NOTICE '数据完整性检查通过！';
    ELSE
        RAISE WARNING '数据完整性检查失败，请检查数据文件！';
    END IF;
END $$;

-- 8. 创建卖家绩效视图
CREATE OR REPLACE VIEW v_seller_performance AS
SELECT 
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT oi.order_id) as total_orders,
    COALESCE(SUM(oi.price), 0) as total_revenue,
    COALESCE(AVG(oi.price), 0) as avg_order_value,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    MIN(o.order_purchase_timestamp) as first_order_date,
    MAX(o.order_purchase_timestamp) as last_order_date,
    CASE 
        WHEN COUNT(DISTINCT oi.order_id) = 0 THEN '无交易'
        WHEN COUNT(DISTINCT oi.order_id) <= 5 THEN '低频卖家'
        WHEN COUNT(DISTINCT oi.order_id) <= 20 THEN '中频卖家'
        ELSE '高频卖家'
    END as frequency_category
FROM olist_sellers s
LEFT JOIN olist_order_items oi ON s.seller_id = oi.seller_id
LEFT JOIN olist_orders o ON oi.order_id = o.order_id AND o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state, s.seller_city;

-- 9. 显示数据概览
SELECT '数据初始化完成，可用视图：' as info;
SELECT '   1. v_seller_performance - 卖家绩效视图' as view_list;
SELECT '   2. 直接查询原始表进行分析' as view_list;
SELECT '';
SELECT '数据预览：' as preview;
SELECT '卖家表样例：' as table_name, seller_id, seller_state FROM olist_sellers LIMIT 3;
SELECT '订单表样例：' as table_name, order_id, order_status FROM olist_orders LIMIT 3;
SELECT '订单商品样例：' as table_name, order_id, seller_id, price FROM olist_order_items LIMIT 3;
