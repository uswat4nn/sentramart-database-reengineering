-- UAS ADS: 02_schema_v2.sql 
DROP SCHEMA IF EXISTS v2 CASCADE;
CREATE SCHEMA v2;
SET search_path TO v2;

-- 1. Master Categories
CREATE TABLE v2.categories (
    category_id     INT PRIMARY KEY,
    category_name   TEXT NOT NULL
);

-- 2. Master Sellers
CREATE TABLE v2.sellers (
    seller_id       INT PRIMARY KEY,
    seller_name     TEXT NOT NULL,
    seller_type     TEXT,
    city            TEXT,
    province        TEXT,
    joined_at       TIMESTAMP,
    rating          NUMERIC(3,2)
);

-- 3. Master Customers (email NOT NULL, tanpa UNIQUE karena ada pelanggan daftar ulang di legacy)
CREATE TABLE v2.customers (
    customer_id     INT PRIMARY KEY,
    full_name       TEXT NOT NULL,
    email           TEXT NOT NULL,
    phone           TEXT,
    city            TEXT,
    province        TEXT,
    registered_at   TIMESTAMP,
    tier            TEXT
);

-- 4. Products (Eliminasi Floating Point & Proteksi Stok Negatif)
CREATE TABLE v2.products (
    product_id      INT PRIMARY KEY,
    seller_id       INT NOT NULL REFERENCES v2.sellers(seller_id),
    category_id     INT NOT NULL REFERENCES v2.categories(category_id),
    product_name    TEXT NOT NULL,
    price           NUMERIC(15,2) NOT NULL CHECK (price >= 0),
    stock           INT NOT NULL CHECK (stock >= 0), -- PENCEGAH OVERSELLING
    is_flash_sale   BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Flash Sale Events & Items
CREATE TABLE v2.flash_sale_events (
    event_id        TEXT PRIMARY KEY,
    event_name      TEXT NOT NULL,
    start_at        TIMESTAMP NOT NULL,
    end_at          TIMESTAMP NOT NULL
);

CREATE TABLE v2.flash_sale_items (
    event_id        TEXT NOT NULL REFERENCES v2.flash_sale_events(event_id) ON DELETE CASCADE,
    product_id      INT NOT NULL REFERENCES v2.products(product_id) ON DELETE CASCADE,
    flash_price     NUMERIC(15,2) NOT NULL CHECK (flash_price >= 0),
    quota           INT NOT NULL CHECK (quota >= 0),
    PRIMARY KEY (event_id, product_id)
);

-- 6. Orders (Range Partitioning Berdasarkan order_date)
CREATE TABLE v2.orders (
    order_id        BIGINT NOT NULL,
    customer_id     INT NOT NULL REFERENCES v2.customers(customer_id),
    order_date      TIMESTAMP NOT NULL,
    status          TEXT NOT NULL CHECK (status IN ('CREATED', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'REFUNDED')),
    shipping_fee    NUMERIC(15,2) DEFAULT 0 CHECK (shipping_fee >= 0),
    discount        NUMERIC(15,2) DEFAULT 0 CHECK (discount >= 0),
    total_amount    NUMERIC(15,2) NOT NULL CHECK (total_amount >= 0),
    voucher_code    TEXT,
    shipping_city   TEXT,
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);

-- Sub-partisi Tahunan
CREATE TABLE v2.orders_2024 PARTITION OF v2.orders
    FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');

CREATE TABLE v2.orders_2025 PARTITION OF v2.orders
    FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');

-- 7. Order Items
CREATE TABLE v2.order_items (
    order_item_id   BIGINT PRIMARY KEY,
    order_id        BIGINT NOT NULL,
    order_date      TIMESTAMP NOT NULL,
    product_id      INT NOT NULL REFERENCES v2.products(product_id),
    seller_id       INT NOT NULL REFERENCES v2.sellers(seller_id),
    qty             INT NOT NULL CHECK (qty > 0),
    unit_price      NUMERIC(15,2) NOT NULL CHECK (unit_price >= 0),
    subtotal        NUMERIC(15,2) NOT NULL CHECK (subtotal >= 0),
    FOREIGN KEY (order_id, order_date) REFERENCES v2.orders(order_id, order_date) ON DELETE CASCADE
);

-- 8. Payments (Menyertakan order_date untuk Composite Foreign Key)
CREATE TABLE v2.payments (
    payment_id      BIGINT PRIMARY KEY,
    order_id        BIGINT NOT NULL,
    order_date      TIMESTAMP NOT NULL,
    method          TEXT NOT NULL,
    amount          NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    status          TEXT NOT NULL CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'EXPIRED', 'REFUNDED')),
    gateway_ref     TEXT UNIQUE, -- CONSTRAINT PENCEGAH DOUBLE CHARGING
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at         TIMESTAMP,
    FOREIGN KEY (order_id, order_date) REFERENCES v2.orders(order_id, order_date)
);
