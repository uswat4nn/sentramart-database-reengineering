-- UAS ADS: 04_optimization.sql 
SET search_path TO v2;

-- 1. Index untuk Q1: Riwayat Pesanan Customer (customer_id, order_date DESC)
CREATE INDEX IF NOT EXISTS idx_orders_customer_date 
ON v2.orders (customer_id, order_date DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_order_lookup 
ON v2.order_items (order_id);

-- 2. Index untuk Q2: Dashboard Penjualan Seller (seller_id di order_items)
CREATE INDEX IF NOT EXISTS idx_order_items_seller_id 
ON v2.order_items (seller_id);

-- 3. Composite Index untuk Q4 & Laporan Harian: (order_date, status) INCLUDE total_amount
CREATE INDEX IF NOT EXISTS idx_orders_date_status_covering 
ON v2.orders (order_date, status) INCLUDE (total_amount);

-- 4. Indeks untuk Q5: Top Produk Terlaris (product_id & order_date filter)
CREATE INDEX IF NOT EXISTS idx_order_items_product_id 
ON v2.order_items (product_id);

-- 5. Indeks untuk Q6: Rekonsiliasi Status Pembayaran Pending
CREATE INDEX IF NOT EXISTS idx_payments_pending_created 
ON v2.payments (status, created_at) 
WHERE status = 'PENDING';

-- 6. Partial Index untuk Pencarian Cepat Produk Flash Sale
CREATE INDEX IF NOT EXISTS idx_products_flash_active 
ON v2.products (product_id, price, stock) 
WHERE is_flash_sale = TRUE AND stock > 0;

-- Refresh data statistik optimizer PostgreSQL
ANALYZE v2.categories;
ANALYZE v2.sellers;
ANALYZE v2.customers;
ANALYZE v2.products;
ANALYZE v2.orders;
ANALYZE v2.order_items;
ANALYZE v2.payments;
