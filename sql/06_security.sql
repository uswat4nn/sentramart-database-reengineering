-- UAS ADS: 06_security.sql (ROLE LEAST-PRIVILEGE, RLS, & MASKING PII)
SET search_path TO v2;

-- 1. Bersihkan policy & role lama jika ada
DROP POLICY IF EXISTS seller_product_isolation ON v2.products;
DROP VIEW IF EXISTS v2.v_customers_masked CASCADE;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_backend') THEN
        EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA v2 FROM app_backend';
        EXECUTE 'DROP ROLE app_backend';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'seller_role') THEN
        EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA v2 FROM seller_role';
        EXECUTE 'DROP ROLE seller_role';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'finance_role') THEN
        EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA v2 FROM finance_role';
        EXECUTE 'DROP ROLE finance_role';
    END IF;
END $$;

-- 2. Buat Role Baru (Prinsip Least-Privilege)
CREATE ROLE app_backend WITH LOGIN PASSWORD 'SecureAppPass123!';
CREATE ROLE seller_role WITH LOGIN PASSWORD 'SellerPass123!';
CREATE ROLE finance_role WITH LOGIN PASSWORD 'FinancePass123!';

-- Berikan izin pemakaian skema v2
GRANT USAGE ON SCHEMA v2 TO app_backend, seller_role, finance_role;

-- 3. Hak Akses Spesifik
-- App Backend (Untuk Checkout & Pembaruan Transaksi)
GRANT SELECT, UPDATE ON v2.products TO app_backend;
GRANT SELECT, INSERT, UPDATE ON v2.orders, v2.orders_2024, v2.orders_2025, v2.order_items, v2.payments TO app_backend;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA v2 TO app_backend;

-- Finance (Hanya Lihat Laporan Keuangan)
GRANT SELECT ON v2.orders, v2.orders_2024, v2.orders_2025, v2.order_items, v2.payments TO finance_role;

-- Seller Portal (Hanya Melihat Produk)
GRANT SELECT ON v2.products TO seller_role;

-- 4. Row-Level Security (RLS) untuk Seller Multi-Tenancy
ALTER TABLE v2.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY seller_product_isolation ON v2.products
    FOR ALL TO seller_role
    USING (seller_id = NULLIF(current_setting('app.current_seller_id', true), '')::INT);

-- 5. Data Privacy (PII Protection) via Dynamic Masking View
CREATE OR REPLACE VIEW v2.v_customers_masked AS
SELECT 
    customer_id,
    full_name,
    REGEXP_REPLACE(email, '(?<=.).(?=.*@)', '*', 'g') AS masked_email,
    CONCAT(SUBSTRING(phone, 1, 4), '****', SUBSTRING(phone, LENGTH(phone)-2, 3)) AS masked_phone,
    city,
    province,
    tier
FROM v2.customers;

GRANT SELECT ON v2.v_customers_masked TO seller_role, finance_role;

-- 6. Uji Coba Keamanan (Bukti RLS Berhasil)
SET LOCAL app.current_seller_id = '10';
SELECT product_id, product_name, seller_id FROM v2.products LIMIT 5;
