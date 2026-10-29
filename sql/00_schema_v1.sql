-- =====================================================================
-- SentraMart — Skema Database v1 (LEGACY / KONDISI SAAT INI)
-- UAS Advanced Database Systems — Universitas Cakrawala
-- ---------------------------------------------------------------------
-- Skema ini adalah skema produksi yang dibuat tim awal SentraMart pada
-- 2022 dan dipakai hingga insiden Flash Sale 12.12.2025.
-- Skema ini SENGAJA dipertahankan apa adanya. Tugas Anda adalah
-- menganalisis kelemahannya dan merancang skema v2.
-- =====================================================================
DROP SCHEMA IF EXISTS legacy CASCADE;
CREATE SCHEMA legacy;
SET search_path TO legacy;

CREATE TABLE categories (
    category_id     INTEGER PRIMARY KEY,
    category_name   TEXT
);

CREATE TABLE sellers (
    seller_id       INTEGER PRIMARY KEY,
    seller_name     TEXT,
    seller_type     TEXT,            -- regular / star / official
    city            TEXT,
    province        TEXT,
    joined_at       TIMESTAMP,
    rating          DOUBLE PRECISION
);

CREATE TABLE customers (
    customer_id     INTEGER PRIMARY KEY,
    full_name       TEXT,
    email           TEXT,            -- PII
    phone           TEXT,            -- PII
    city            TEXT,
    province        TEXT,
    registered_at   TIMESTAMP,
    tier            TEXT
);

CREATE TABLE products (
    product_id      INTEGER PRIMARY KEY,
    seller_id       INTEGER,
    category_id     INTEGER,
    product_name    TEXT,
    price           DOUBLE PRECISION,
    stock           INTEGER,
    is_flash_sale   BOOLEAN,
    created_at      TIMESTAMP
);

-- Atribut produk yang berbeda-beda per kategori disimpan sebagai EAV
CREATE TABLE product_attributes (
    product_id      INTEGER,
    attr_name       TEXT,
    attr_value      TEXT
);

CREATE TABLE orders (
    order_id        BIGINT PRIMARY KEY,
    customer_id     INTEGER,
    order_date      TIMESTAMP,
    status          TEXT,            -- CREATED / PAID / SHIPPED / DELIVERED / CANCELLED / REFUNDED
    shipping_fee    DOUBLE PRECISION,
    discount        DOUBLE PRECISION,
    total_amount    DOUBLE PRECISION,
    voucher_code    TEXT,
    shipping_city   TEXT
);

CREATE TABLE order_items (
    order_item_id   BIGINT PRIMARY KEY,
    order_id        BIGINT,
    product_id      INTEGER,
    seller_id       INTEGER,
    qty             INTEGER,
    unit_price      DOUBLE PRECISION,
    subtotal        DOUBLE PRECISION
);

CREATE TABLE payments (
    payment_id      BIGINT PRIMARY KEY,
    order_id        BIGINT,
    method          TEXT,
    amount          DOUBLE PRECISION,
    status          TEXT,            -- PENDING / SUCCESS / FAILED / EXPIRED / REFUNDED
    gateway_ref     TEXT,            -- referensi transaksi dari payment gateway
    created_at      TIMESTAMP,
    paid_at         TIMESTAMP
);

CREATE TABLE flash_sale_events (
    event_id        TEXT,
    event_name      TEXT,
    start_at        TIMESTAMP,
    end_at          TIMESTAMP
);

CREATE TABLE flash_sale_items (
    event_id        TEXT,
    product_id      INTEGER,
    flash_price     DOUBLE PRECISION,
    quota           INTEGER
);
