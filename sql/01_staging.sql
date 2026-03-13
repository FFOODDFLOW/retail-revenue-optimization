
-- ==================================================
-- 01_staging.sql
-- Project: Retail Revenue Optimization (Online Retail II - UCI)
-- Database: PostgreSQL
--
-- Purpose
--   1) Create schemas used by this project
--   2) Create a raw staging table that mirrors the source CSV
--   3) Add indexes that make downstream modeling faster
--
-- Key Design Principle
--   Keep the staging layer as close to the raw source as possible.
--   Do NOT “clean” business logic here (returns/cancellations/filters).
--   That belongs in the analytics layer (facts/dims/views).
-- ==================================================


-- --------------------------------------------------
-- 0) Create schemas (namespaces)
-- --------------------------------------------------
-- staging: raw ingestion layer (source-of-truth in the database)
-- retail : modeled analytics layer (dimensions, facts, KPI views)
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS retail;


-- --------------------------------------------------
-- 1) Drop and recreate the staging table (repeatable pipeline)
-- --------------------------------------------------
-- During development, you will run this script multiple times.
-- Dropping ensures you can rebuild cleanly without manual cleanup.
DROP TABLE IF EXISTS staging.online_retail_raw;


-- --------------------------------------------------
-- 2) Create raw staging table matching the CSV columns
-- --------------------------------------------------
-- IMPORTANT:
-- customer_id is NUMERIC (not INTEGER) because the raw dataset stores
-- CustomerID as floating-point formatted values like "13085.0".
-- We normalize/cast it downstream in dim_customer.
CREATE TABLE staging.online_retail_raw (
    invoice_no    TEXT,             -- Invoice identifier (can start with 'C' for cancellations)
    stock_code    TEXT,             -- Product identifier
    description   TEXT,             -- Product description/name
    quantity      INTEGER,          -- Units per line item (can be negative for returns)
    invoice_date  TIMESTAMP,        -- Timestamp of purchase
    unit_price    NUMERIC(10, 2),   -- Price per unit
    customer_id   NUMERIC,          -- Stored as numeric because source has values like 13085.0
    country       TEXT              -- Country associated with the transaction/customer
);


-- --------------------------------------------------
-- 3) Indexes to speed up downstream transformations and joins
-- --------------------------------------------------
-- These are especially helpful with ~1M+ rows.
-- They are not required, but they reduce latency during modeling.
CREATE INDEX IF NOT EXISTS ix_raw_invoice_no
    ON staging.online_retail_raw (invoice_no);

CREATE INDEX IF NOT EXISTS ix_raw_customer_id
    ON staging.online_retail_raw (customer_id);

CREATE INDEX IF NOT EXISTS ix_raw_invoice_date
    ON staging.online_retail_raw (invoice_date);

CREATE INDEX IF NOT EXISTS ix_raw_stock_code
    ON staging.online_retail_raw (stock_code);


-- --------------------------------------------------
-- 4) Load step (documented)
-- --------------------------------------------------
-- This script creates the table, but it does NOT load the CSV by itself.
-- Load is done via psql using \copy (recommended for large files on Windows):
--
-- \copy staging.online_retail_raw FROM 'C:/FULL/PATH/data_raw/online_retail_raw.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'LATIN1');
--
-- Expected successful load message:
--   COPY 1067371
--
-- After loading, verify:
--   SELECT COUNT(*) FROM staging.online_retail_raw;
--   (Expected: 1067371)
-- --------------------------------------------------


-- --------------------------------------------------
-- 5) Optional sanity checks (run after load)
-- --------------------------------------------------
-- Quick profile to understand the raw dataset characteristics.
-- These checks help explain business rules later (cancellations/returns).
--
-- SELECT
--   COUNT(*) AS rows,
--   COUNT(customer_id) AS customer_id_nonnull,
--   COUNT(*) FILTER (WHERE invoice_no LIKE 'C%') AS canceled_rows,
--   COUNT(*) FILTER (WHERE quantity < 0) AS negative_qty_rows
-- FROM staging.online_retail_raw;
--
-- Notes:
-- - Cancellations often appear as invoice numbers starting with 'C'
-- - Negative quantity indicates returns/adjustments
-- - Null customer_id indicates anonymous/untracked customers
-- --------------------------------------------------
