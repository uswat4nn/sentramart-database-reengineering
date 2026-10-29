-- =====================================================================
-- SentraMart — Workload Query Produksi (diambil dari slow query log)
-- UAS Advanced Database Systems — Universitas Cakrawala
-- ---------------------------------------------------------------------
-- Delapan query berikut adalah query yang paling sering muncul di
-- slow query log selama periode November–Desember 2025.
-- Kolom "Frekuensi" dan "SLA" adalah kebutuhan bisnis dari tim produk.
-- Jalankan setiap query dengan:  EXPLAIN (ANALYZE, BUFFERS) <query>;
-- Catatan:
-- 1) Dataset berhenti di 31-12-2025, sehingga "hari ini" pada query di
--    bawah dianggap 31-12-2025 23:59.
-- 2) Dataset adalah SAMPEL ±4% dari volume produksi. Target SLA di bawah
--    sudah disesuaikan untuk ukuran sampel ini. Ukur di laptop Anda
--    sendiri (cache hangat: jalankan 3x, ambil median).
-- 3) Hasil query setelah optimasi HARUS identik dengan hasil sebelum
--    optimasi (kecuali Anda menjelaskan perbaikan kualitas data).
-- =====================================================================
SET search_path TO legacy;

-- ---------------------------------------------------------------------
-- Q1. Riwayat pesanan pelanggan (halaman "Pesanan Saya" di aplikasi)
--     Frekuensi: ±1.200 request/menit saat jam sibuk  |  SLA: < 10 ms
-- ---------------------------------------------------------------------
SELECT o.order_id, o.order_date, o.status, o.total_amount,
       COUNT(oi.order_item_id) AS jumlah_item
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.customer_id = 13211
GROUP BY o.order_id, o.order_date, o.status, o.total_amount
ORDER BY o.order_date DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Q2. Dashboard penjualan harian seller (Seller Center)
--     Frekuensi: ±300 request/menit  |  SLA: < 30 ms
-- ---------------------------------------------------------------------
SELECT date_trunc('day', o.order_date) AS tanggal,
       COUNT(DISTINCT o.order_id)      AS jumlah_order,
       SUM(oi.subtotal)                AS omzet
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE oi.seller_id = 579
  AND o.order_date >= '2025-11-01' AND o.order_date < '2025-12-01'
  AND upper(trim(o.status)) IN ('PAID', 'SHIPPED', 'DELIVERED')
GROUP BY 1
ORDER BY 1;

-- ---------------------------------------------------------------------
-- Q3. Filter produk berdasarkan spesifikasi (kategori Handphone & Tablet:
--     RAM 8 GB, jaringan 5G, harga 2–5 juta). Atribut disimpan dalam EAV.
--     Frekuensi: ±500 request/menit  |  SLA: < 10 ms
-- ---------------------------------------------------------------------
SELECT p.product_id, p.product_name, p.price
FROM products p
JOIN product_attributes a1 ON a1.product_id = p.product_id AND a1.attr_name = 'ram_gb'  AND a1.attr_value = '8'
JOIN product_attributes a2 ON a2.product_id = p.product_id AND a2.attr_name = 'network' AND a2.attr_value = '5G'
WHERE p.category_id = 1
  AND p.price BETWEEN 2000000 AND 5000000
  AND p.stock > 0
ORDER BY p.price
LIMIT 50;

-- ---------------------------------------------------------------------
-- Q4. Rekap order pada satu tanggal (dipakai tim CS & finance)
--     Frekuensi: ±20 request/menit  |  SLA: < 10 ms
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS jumlah_order, SUM(total_amount) AS gmv
FROM orders
WHERE DATE(order_date) = '2025-12-12'
  AND status = 'DELIVERED';

-- ---------------------------------------------------------------------
-- Q5. Top 10 produk terlaris 30 hari terakhir per kategori (homepage)
--     Frekuensi: dibaca setiap kali homepage dibuka; data boleh tertinggal
--     maksimal 10 menit  |  SLA: < 20 ms
-- ---------------------------------------------------------------------
WITH penjualan AS (
    SELECT p.category_id, oi.product_id, SUM(oi.qty) AS unit_terjual
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_date >= TIMESTAMP '2025-12-31 23:59:59' - INTERVAL '30 days'
      AND upper(trim(o.status)) NOT IN ('CANCELLED', 'REFUNDED')
    GROUP BY p.category_id, oi.product_id
), ranking AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY unit_terjual DESC) AS rn
    FROM penjualan
)
SELECT c.category_name, r.product_id, r.unit_terjual, r.rn
FROM ranking r JOIN categories c ON c.category_id = r.category_id
WHERE r.rn <= 10
ORDER BY c.category_name, r.rn;

-- ---------------------------------------------------------------------
-- Q6. Job rekonsiliasi: pembayaran PENDING lebih dari 24 jam
--     Frekuensi: setiap 5 menit  |  SLA: < 5 ms
-- ---------------------------------------------------------------------
SELECT payment_id, order_id, method, amount, created_at
FROM payments
WHERE status = 'PENDING'
  AND created_at < TIMESTAMP '2025-12-31 23:59:59' - INTERVAL '24 hours'
ORDER BY created_at;

-- ---------------------------------------------------------------------
-- Q7. Pengecekan callback payment gateway (dipanggil SETIAP callback)
--     Frekuensi: ±3.000 request/menit saat flash sale  |  SLA: < 2 ms
-- ---------------------------------------------------------------------
SELECT payment_id, order_id, status
FROM payments
WHERE gateway_ref = 'PGEB8D85CE168E8B';

-- ---------------------------------------------------------------------
-- Q8. Laporan pendapatan bulanan per provinsi (tim finance, tiap tutup buku)
--     Frekuensi: beberapa kali per hari, dijalankan di database produksi
--     SLA: < 50 ms dan tidak boleh membebani transaksi checkout
-- ---------------------------------------------------------------------
SELECT date_trunc('month', o.order_date)::date AS bulan,
       c.province,
       COUNT(*)            AS jumlah_order,
       SUM(o.total_amount) AS pendapatan
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
  AND upper(trim(o.status)) IN ('DELIVERED', 'SHIPPED', 'PAID')
GROUP BY 1, 2
ORDER BY 1, 4 DESC;

-- Mengukur baseline Q1 di skema legacy
EXPLAIN (ANALYZE, BUFFERS)
SELECT * 
FROM legacy.orders 
WHERE order_date >= '2025-12-01' 
  AND order_date < '2025-12-13' 
  AND status = 'PAID';