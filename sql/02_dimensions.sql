
-- ==================================================
-- 02_dimensions.sql
-- Project: Retail Revenue Optimization (Online Retail II - UCI)
-- Database: PostgreSQL
--
-- Purpose
--   Build clean dimension tables from the raw staging layer.
--
-- Design notes
--   - Staging preserves raw source quirks
--   - Dimensions enforce clean keys and consistent attributes
--   - Casting and filtering happen here, not during ingestion
-- ==================================================


-- --------------------------------------------------
-- 0) Ensure analytics schema exists
-- --------------------------------------------------
CREATE SCHEMA IF NOT EXISTS retail;


-- --------------------------------------------------
-- 1) Drop existing dimensions (repeatable pipeline)
-- --------------------------------------------------
DROP TABLE IF EXISTS retail.dim_product CASCADE;
DROP TABLE IF EXISTS retail.dim_customer CASCADE;
DROP TABLE IF EXISTS retail.dim_date CASCADE;


-- --------------------------------------------------
-- 2) Product dimension
-- Grain: one row per product (stock_code)
-- --------------------------------------------------
CREATE TABLE retail.dim_product AS
SELECT
    stock_code AS product_id,
    MAX(description) AS product_description
FROM staging.online_retail_raw
WHERE stock_code IS NOT NULL
GROUP BY stock_code;

ALTER TABLE retail.dim_product
    ADD CONSTRAINT pk_dim_product PRIMARY KEY (product_id);


-- --------------------------------------------------
-- 3) Customer dimension
-- Grain: one row per customer_id
--
-- Notes:
--   - customer_id is NUMERIC in staging due to source formatting
--   - Only whole-number values are retained
--   - NULL customer_id rows represent anonymous customers and
--     are intentionally excluded from the dimension
-- --------------------------------------------------
CREATE TABLE retail.dim_customer AS
SELECT
    customer_id::INTEGER AS customer_id,
    MAX(country) AS country
FROM staging.online_retail_raw
WHERE customer_id IS NOT NULL
  AND customer_id = FLOOR(customer_id)
GROUP BY customer_id::INTEGER;

ALTER TABLE retail.dim_customer
    ADD CONSTRAINT pk_dim_customer PRIMARY KEY (customer_id);


-- --------------------------------------------------
-- 4) Date dimension
-- Grain: one row per calendar date
-- --------------------------------------------------
CREATE TABLE retail.dim_date AS
SELECT DISTINCT
    invoice_date::DATE AS date_id,
    EXTRACT(YEAR  FROM invoice_date)::INT AS year,
    EXTRACT(MONTH FROM invoice_date)::INT AS month,
    EXTRACT(DAY   FROM invoice_date)::INT AS day,
    EXTRACT(DOW   FROM invoice_date)::INT AS day_of_week,
    TO_CHAR(invoice_date::DATE, 'YYYY-MM') AS year_month
FROM staging.online_retail_raw
WHERE invoice_date IS NOT NULL;

ALTER TABLE retail.dim_date
    ADD CONSTRAINT pk_dim_date PRIMARY KEY (date_id);


-- --------------------------------------------------
-- 5) Helpful indexes for joins and filters
-- --------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_dim_date_year_month
    ON retail.dim_date (year_month);


-- --------------------------------------------------
-- 6) Optional QA checks (run manually)
-- --------------------------------------------------
-- Null checks (should all be 0)
-- SELECT COUNT(*) FROM retail.dim_product  WHERE product_id IS NULL;
-- SELECT COUNT(*) FROM retail.dim_customer WHERE customer_id IS NULL;
-- SELECT COUNT(*) FROM retail.dim_date     WHERE date_id IS NULL;

-- Duplicate key checks (should all be 0)
-- SELECT COUNT(*) - COUNT(DISTINCT product_id)  AS dup_products  FROM retail.dim_product;
-- SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS dup_customers FROM retail.dim_customer;
-- SELECT COUNT(*) - COUNT(DISTINCT date_id)     AS dup_dates     FROM retail.dim_date;
