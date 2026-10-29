-- UAS ADS: 03_migration.sql (ETL & PEMBERSIHAN DATA LENGKAP)
SET search_path TO v2;

-- 1. Migrasi Master Kategori, Seller, Customer
INSERT INTO v2.categories SELECT category_id, TRIM(category_name) FROM legacy.categories;

INSERT INTO v2.sellers 
SELECT seller_id, TRIM(seller_name), TRIM(seller_type), TRIM(city), TRIM(province), joined_at, rating::NUMERIC(3,2) 
FROM legacy.sellers;

INSERT INTO v2.customers 
SELECT customer_id, TRIM(full_name), LOWER(TRIM(email)), phone, TRIM(city), TRIM(province), registered_at, TRIM(tier) 
FROM legacy.customers;

-- 2. Migrasi Produk (Aturan: Stok minus di-clamp ke 0)
INSERT INTO v2.products (product_id, seller_id, category_id, product_name, price, stock, is_flash_sale, created_at)
SELECT 
    product_id, seller_id, category_id, TRIM(product_name), 
    price::NUMERIC(15,2), 
    GREATEST(stock, 0), -- Mengubah 32 produk negatif menjadi 0
    COALESCE(is_flash_sale, FALSE), 
    created_at
FROM legacy.products;

-- 3. Migrasi Flash Sale Data
INSERT INTO v2.flash_sale_events SELECT * FROM legacy.flash_sale_events;
INSERT INTO v2.flash_sale_items 
SELECT event_id, product_id, flash_price::NUMERIC(15,2), quota 
FROM legacy.flash_sale_items;

-- 4. Migrasi Orders (Aturan: Normalisasi status UPPER TRIM)
INSERT INTO v2.orders (order_id, customer_id, order_date, status, shipping_fee, discount, total_amount, voucher_code, shipping_city)
SELECT 
    order_id, customer_id, order_date, 
    UPPER(TRIM(status)), -- Menghilangkan spasi 'PAID ' -> 'PAID'
    COALESCE(shipping_fee, 0)::NUMERIC(15,2), 
    COALESCE(discount, 0)::NUMERIC(15,2), 
    total_amount::NUMERIC(15,2), 
    voucher_code, shipping_city
FROM legacy.orders;

-- 5. Migrasi Order Items
INSERT INTO v2.order_items (order_item_id, order_id, order_date, product_id, seller_id, qty, unit_price, subtotal)
SELECT 
    oi.order_item_id, oi.order_id, o.order_date, oi.product_id, oi.seller_id, 
    oi.qty, oi.unit_price::NUMERIC(15,2), oi.subtotal::NUMERIC(15,2)
FROM legacy.order_items oi
JOIN legacy.orders o ON o.order_id = oi.order_id;

-- 6. Migrasi Payments (Aturan: Deduplikasi 18 pembayaran ganda via DISTINCT ON)
INSERT INTO v2.payments (payment_id, order_id, order_date, method, amount, status, gateway_ref, created_at, paid_at)
SELECT DISTINCT ON (TRIM(p.gateway_ref))
    p.payment_id, p.order_id, o.order_date, TRIM(p.method), 
    p.amount::NUMERIC(15,2), UPPER(TRIM(p.status)), 
    TRIM(p.gateway_ref), p.created_at, p.paid_at
FROM legacy.payments p
JOIN legacy.orders o ON o.order_id = p.order_id
WHERE p.gateway_ref IS NOT NULL
ORDER BY TRIM(p.gateway_ref), p.created_at ASC;

-- 7. TABEL REKONSILIASI HASIL MIGRASI
SELECT 'categories' AS tabel, (SELECT COUNT(*) FROM legacy.categories) AS legacy_count, (SELECT COUNT(*) FROM v2.categories) AS v2_count
UNION ALL
SELECT 'sellers', (SELECT COUNT(*) FROM legacy.sellers), (SELECT COUNT(*) FROM v2.sellers)
UNION ALL
SELECT 'customers', (SELECT COUNT(*) FROM legacy.customers), (SELECT COUNT(*) FROM v2.customers)
UNION ALL
SELECT 'products', (SELECT COUNT(*) FROM legacy.products), (SELECT COUNT(*) FROM v2.products)
UNION ALL
SELECT 'orders', (SELECT COUNT(*) FROM legacy.orders), (SELECT COUNT(*) FROM v2.orders)
UNION ALL
SELECT 'order_items', (SELECT COUNT(*) FROM legacy.order_items), (SELECT COUNT(*) FROM v2.order_items)
UNION ALL
SELECT 'payments (berkurang 18 duplikat)', (SELECT COUNT(*) FROM legacy.payments), (SELECT COUNT(*) FROM v2.payments);
