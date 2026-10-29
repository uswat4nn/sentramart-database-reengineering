-- =====================================================================
-- SentraMart — Replikasi Logika Aplikasi LEGACY (penyebab insiden 12.12)
-- UAS Advanced Database Systems — Universitas Cakrawala
-- ---------------------------------------------------------------------
-- Tim backend menuliskan ulang logika checkout & callback pembayaran
-- yang dipakai saat insiden ke dalam fungsi PL/pgSQL agar dapat Anda
-- reproduksi di lab. pg_sleep() mensimulasikan latensi aplikasi
-- (validasi voucher, hitung ongkir, panggilan ke payment gateway).
-- JANGAN ubah fungsi ini — buat versi perbaikan Anda di skema v2.
-- =====================================================================
SET search_path TO legacy;

CREATE SEQUENCE IF NOT EXISTS legacy.order_id_seq START 3000000;
CREATE SEQUENCE IF NOT EXISTS legacy.order_item_id_seq START 3000000;
CREATE SEQUENCE IF NOT EXISTS legacy.payment_id_seq START 8000000;

-- ---------------------------------------------------------------------
-- 1) Checkout satu produk (dipakai untuk flash sale)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION legacy.checkout_legacy(p_customer_id INT, p_product_id INT, p_qty INT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_stock    INT;
    v_price    DOUBLE PRECISION;
    v_seller   INT;
    v_order_id BIGINT;
BEGIN
    -- (a) baca stok saat ini
    SELECT stock, price, seller_id INTO v_stock, v_price, v_seller
    FROM legacy.products WHERE product_id = p_product_id;

    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'Stok tidak cukup (sisa %)', v_stock;
    END IF;

    -- (b) aplikasi memvalidasi voucher & menghitung ongkir (±2 detik saat flash sale)
    PERFORM pg_sleep(2);

    -- (c) kurangi stok
    UPDATE legacy.products SET stock = stock - p_qty WHERE product_id = p_product_id;

    v_order_id := nextval('legacy.order_id_seq');
    INSERT INTO legacy.orders(order_id, customer_id, order_date, status, shipping_fee, discount, total_amount, voucher_code, shipping_city)
    VALUES (v_order_id, p_customer_id, now(), 'CREATED', 0, 0, v_price * p_qty, NULL, NULL);
    INSERT INTO legacy.order_items(order_item_id, order_id, product_id, seller_id, qty, unit_price, subtotal)
    VALUES (nextval('legacy.order_item_id_seq'), v_order_id, p_product_id, v_seller, p_qty, v_price, v_price * p_qty);
    RETURN v_order_id;
END $$;

-- ---------------------------------------------------------------------
-- 2) Callback payment gateway (gateway dapat mengirim ulang callback
--    yang sama bila tidak menerima respons dalam 3 detik)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION legacy.payment_callback_legacy(p_order_id BIGINT, p_gateway_ref TEXT, p_amount DOUBLE PRECISION, p_method TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    -- (a) cek apakah callback ini sudah pernah diproses
    IF EXISTS (SELECT 1 FROM legacy.payments WHERE gateway_ref = p_gateway_ref AND status = 'SUCCESS') THEN
        RETURN 'DUPLICATE_IGNORED';
    END IF;

    -- (b) verifikasi signature & ambil detail transaksi ke gateway (±1 detik)
    PERFORM pg_sleep(1);

    -- (c) catat pembayaran & ubah status order
    INSERT INTO legacy.payments(payment_id, order_id, method, amount, status, gateway_ref, created_at, paid_at)
    VALUES (nextval('legacy.payment_id_seq'), p_order_id, p_method, p_amount, 'SUCCESS', p_gateway_ref, now(), now());
    UPDATE legacy.orders SET status = 'PAID' WHERE order_id = p_order_id;
    RETURN 'OK';
END $$;

-- ---------------------------------------------------------------------
-- 3) Checkout keranjang multi-produk: aplikasi mengurangi stok sesuai
--    URUTAN ITEM DI KERANJANG pengguna (lihat skenario deadlock di README)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION legacy.checkout_cart_legacy(p_customer_id INT, p_product_ids INT[])
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    v_pid INT;
BEGIN
    FOREACH v_pid IN ARRAY p_product_ids LOOP
        UPDATE legacy.products SET stock = stock - 1 WHERE product_id = v_pid;
        PERFORM pg_sleep(1);   -- latensi per item (cek promo per produk)
    END LOOP;
    RETURN 'OK';
END $$;
