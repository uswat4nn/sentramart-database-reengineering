-- SentraMart — AUDIT DATABASE LEGACY v1 (TASK 1 - CPMK1)
SET search_path TO legacy;

-- 1. DATA PROFILING: JUMLAH BARIS SETIAP TABEL AKTUAL
SELECT 'customers' AS nama_tabel, COUNT(*) AS jumlah_baris FROM legacy.customers
UNION ALL SELECT 'sellers', COUNT(*) FROM legacy.sellers
UNION ALL SELECT 'categories', COUNT(*) FROM legacy.categories
UNION ALL SELECT 'products', COUNT(*) FROM legacy.products
UNION ALL SELECT 'product_attributes', COUNT(*) FROM legacy.product_attributes
UNION ALL SELECT 'orders', COUNT(*) FROM legacy.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM legacy.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM legacy.payments
UNION ALL SELECT 'flash_sale_events', COUNT(*) FROM legacy.flash_sale_events
UNION ALL SELECT 'flash_sale_items', COUNT(*) FROM legacy.flash_sale_items
ORDER BY nama_tabel;

-- 2. RENTANG TANGGAL TRANSAKSI
SELECT 
    MIN(order_date) AS order_pertama,
    MAX(order_date) AS order_terakhir,
    COUNT(*) AS total_order
FROM legacy.orders;

-- 3. AUDIT SPASI & INKONSISTENSI STATUS ORDER
SELECT 
    status AS status_asli,
    LENGTH(status) AS panjang_karakter,
    COUNT(*) AS jumlah_baris
FROM legacy.orders
WHERE status LIKE '% ' OR status LIKE ' %' OR status <> UPPER(status)
GROUP BY status, LENGTH(status);

SELECT 
    UPPER(TRIM(status)) AS status_bersih,
    COUNT(*) AS total_pesanan
FROM legacy.orders
GROUP BY UPPER(TRIM(status))
ORDER BY total_pesanan DESC;

-- 4. KUANTIFIKASI INSIDEN 12.12: OVERSELLING (STOK MINUS)
SELECT 
    COUNT(product_id) AS jumlah_produk_oversold,
    SUM(ABS(stock))   AS total_unit_oversold
FROM legacy.products 
WHERE stock < 0;

SELECT product_id, product_name, price, stock 
FROM legacy.products 
WHERE stock < 0 
ORDER BY stock ASC 
LIMIT 10;

-- 5. KUANTIFIKASI INSIDEN 12.12: DOUBLE CHARGING (PEMBAYARAN DUPLIKAT)
WITH duplicate_payments AS (
    SELECT 
        order_id,
        gateway_ref,
        COUNT(*) AS charge_count,
        SUM(amount) AS total_dibayar,
        MIN(amount) AS tagihan_asli
    FROM legacy.payments
    WHERE gateway_ref IS NOT NULL
    GROUP BY order_id, gateway_ref
    HAVING COUNT(*) > 1
)
SELECT 
    COUNT(DISTINCT order_id) AS total_order_double_charge,
    SUM(total_dibayar - tagihan_asli) AS total_kelebihan_tagih_rp
FROM duplicate_payments;

-- 6. AUDIT INKONSISTENSI NILAI FINANSIAL (DOUBLE PRECISION BUG)
SELECT 
    o.order_id,
    o.total_amount,
    (COALESCE(SUM(oi.subtotal), 0) + o.shipping_fee - o.discount) AS total_seharusnya,
    ABS(o.total_amount - (COALESCE(SUM(oi.subtotal), 0) + o.shipping_fee - o.discount)) AS selisih_desimal
FROM legacy.orders o
JOIN legacy.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.total_amount, o.shipping_fee, o.discount
HAVING ABS(o.total_amount - (COALESCE(SUM(oi.subtotal), 0) + o.shipping_fee - o.discount)) > 0.0001
ORDER BY selisih_desimal DESC
LIMIT 10;

-- 7. AUDIT KETIADAAN FOREIGN KEY & CONSTRAINT PADA SKEMA LEGACY
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'legacy' 
  AND tc.constraint_type = 'FOREIGN KEY';

-- 8. AUDIT KUOTA FLASH SALE 12.12 YANG JEBOL
SELECT 
    fsi.event_id,
    fse.event_name,
    fsi.product_id,
    p.product_name,
    fsi.flash_price,
    fsi.quota,
    p.stock AS sisa_stok_tercatat
FROM legacy.flash_sale_items fsi
JOIN legacy.flash_sale_events fse ON fse.event_id = fsi.event_id
JOIN legacy.products p ON p.product_id = fsi.product_id
WHERE fse.start_at::date = '2025-12-12' OR fse.event_name ILIKE '%12.12%'
ORDER BY p.stock ASC
LIMIT 10;
