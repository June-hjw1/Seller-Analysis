CREATE TABLE IF NOT EXISTS olist_sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5),
    seller_city VARCHAR(50),
    seller_state VARCHAR(2)
);
CREATE TABLE IF NOT EXISTS olist_order_items (
    order_id VARCHAR(32),
    order_item_id INTEGER,
    product_id VARCHAR(32),
    seller_id VARCHAR(32),
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);
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
INSERT INTO olist_sellers VALUES 
('3442f8959a84dea7ee197c632cb2df15', '13023', 'campinas', 'SP'),
('d1b65fc7debc3361ea86b5f14c68d2e2', '13844', 'mogi guacu', 'SP');

INSERT INTO olist_order_items VALUES
('e481f51cbdc54678b7cc49136f2d6af7', 1, '87285b34884572647811a353c7ac498a', 
 '3442f8959a84dea7ee197c632cb2df15', '2017-10-02 10:15:31', 29.90, 8.72);
