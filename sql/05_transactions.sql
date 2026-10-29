-- UAS ADS: 05_transactions.sql (STORED PROCEDURES & ANTI-DEADLOCK)
SET search_path TO v2;

-- Buat Sequence untuk penomoran ID baru
CREATE SEQUENCE IF NOT EXISTS v2.order_id_seq START 4000000;
CREATE SEQUENCE IF NOT EXISTS v2.order_item_id_seq START 4000000;
CREATE SEQUENCE IF NOT EXISTS v2.payment_id_seq START 9000000;

-- 1. CHECKOUT BEBAS OVERSELLING (Skenario K1 Solved via Pessimistic Lock)
CREATE OR REPLACE FUNCTION v2.checkout_safe(
    p_customer_id INT,
    p_product_id INT,
    p_qty INT
) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_stock    INT;
    v_price    NUMERIC(15,2);
    v_seller   INT;
    v_order_id BIGINT;
    v_now      TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    -- Mengunci baris produk secara eksklusif (FOR UPDATE)
    SELECT stock, price, seller_id INTO v_stock, v_price, v_seller 
    FROM v2.products 
    WHERE product_id = p_product_id 
    FOR UPDATE;

    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'Stok tidak cukup! Tersisa: %, Diminta: %', v_stock, p_qty;
    END IF;

    -- Pengurangan stok aman
    UPDATE v2.products 
    SET stock = stock - p_qty 
    WHERE product_id = p_product_id;

    -- Insert ke orders & order_items
    v_order_id := nextval('v2.order_id_seq');
    INSERT INTO v2.orders(order_id, customer_id, order_date, status, shipping_fee, discount, total_amount)
    VALUES (v_order_id, p_customer_id, v_now, 'CREATED', 0, 0, v_price * p_qty);

    INSERT INTO v2.order_items(order_item_id, order_id, order_date, product_id, seller_id, qty, unit_price, subtotal)
    VALUES (nextval('v2.order_item_id_seq'), v_order_id, v_now, p_product_id, v_seller, p_qty, v_price, v_price * p_qty);

    RETURN v_order_id;
END $$;

-- 2. CALLBACK PEMBAYARAN IDEMPOTEN (Skenario K2 Solved via ON CONFLICT)
CREATE OR REPLACE FUNCTION v2.payment_callback_safe(
    p_order_id BIGINT,
    p_order_date TIMESTAMP,
    p_gateway_ref TEXT,
    p_amount NUMERIC,
    p_method TEXT
) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    v_inserted_id BIGINT;
BEGIN
    -- Insert payment dengan pencegahan duplikasi atomik
    INSERT INTO v2.payments (payment_id, order_id, order_date, method, amount, status, gateway_ref, paid_at)
    VALUES (nextval('v2.payment_id_seq'), p_order_id, p_order_date, p_method, p_amount, 'SUCCESS', p_gateway_ref, CURRENT_TIMESTAMP)
    ON CONFLICT (gateway_ref) DO NOTHING
    RETURNING payment_id INTO v_inserted_id;

    -- Jika v_inserted_id NULL, artinya callback ini adalah retry duplikat
    IF v_inserted_id IS NULL THEN
        RETURN 'DUPLICATE_PAYMENT_SAFELY_IGNORED';
    END IF;

    -- Perbarui status order menjadi PAID
    UPDATE v2.orders 
    SET status = 'PAID' 
    WHERE order_id = p_order_id AND order_date = p_order_date;

    RETURN 'PAYMENT_SUCCESSFULLY_RECORDED';
END $$;


-- 3. CHECKOUT MULTI-ITEM BEBAS DEADLOCK (Skenario K3 Solved via Sorting ID)
CREATE OR REPLACE FUNCTION v2.checkout_cart_safe(
    p_customer_id INT,
    p_product_ids INT[]
) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    v_pid INT;
BEGIN
    -- Urutkan ID produk ASCENDING untuk mengeliminasi deadlocks
    FOR v_pid IN 
        SELECT unnest(p_product_ids) AS pid ORDER BY pid ASC
    LOOP
        PERFORM stock 
        FROM v2.products 
        WHERE product_id = v_pid 
        FOR UPDATE;

        UPDATE v2.products 
        SET stock = stock - 1 
        WHERE product_id = v_pid;
    END LOOP;

    RETURN 'CART_CHECKOUT_SUCCESS';
END $$;
