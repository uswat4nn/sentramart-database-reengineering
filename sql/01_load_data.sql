SET search_path TO legacy;

COPY legacy.categories 
FROM '/tmp/data/categories.csv' 
WITH (FORMAT csv, HEADER true);

COPY legacy.sellers 
FROM '/tmp/data/sellers.csv' 
WITH (FORMAT csv, HEADER true);

COPY legacy.customers 
FROM '/tmp/data/customers.csv' 
WITH (FORMAT csv, HEADER true);

COPY legacy.products 
FROM '/tmp/data/products.csv' 
WITH (FORMAT csv, HEADER true);

COPY legacy.product_attributes 
FROM '/tmp/data/product_attributes.csv' 
WITH (FORMAT csv, HEADER true);

COPY legacy.orders 
FROM '/tmp/data/orders.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY legacy.order_items 
FROM '/tmp/data/order_items.csv' 
WITH (FORMAT csv, HEADER true);

COPY legacy.payments 
FROM '/tmp/data/payments.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY legacy.flash_sale_events 
FROM '/tmp/data/flash_sale_events.csv' 
WITH (FORMAT csv, HEADER true);

COPY legacy.flash_sale_items 
FROM '/tmp/data/flash_sale_items.csv' 
WITH (FORMAT csv, HEADER true);

ANALYZE;

-- Verifikasi jumlah baris data
SELECT 'customers' AS tabel, COUNT(*) FROM legacy.customers UNION ALL
SELECT 'sellers', COUNT(*) FROM legacy.sellers UNION ALL
SELECT 'products', COUNT(*) FROM legacy.products UNION ALL
SELECT 'product_attributes', COUNT(*) FROM legacy.product_attributes UNION ALL
SELECT 'orders', COUNT(*) FROM legacy.orders UNION ALL
SELECT 'order_items', COUNT(*) FROM legacy.order_items UNION ALL
SELECT 'payments', COUNT(*) FROM legacy.payments UNION ALL
SELECT 'flash_sale_items', COUNT(*) FROM legacy.flash_sale_items;