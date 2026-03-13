-- ============================================================
-- 03_fact_sales.sql  (Option B: INCLUDE cancellations)
-- Purpose:
--   Build analytics fact table that keeps cancellations/credit notes
--   so "net revenue" reflects real financial reversals.
--
-- Key change vs prior version:
--   We NO LONGER filter out invoice_no LIKE 'C%'.
--   Instead, we keep those rows and flag them as is_canceled.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS retail;

-- 1) Drop the existing fact table (CASCADE drops dependent views too, if any)
DROP TABLE IF EXISTS retail.fact_sales CASCADE;

-- 2) Recreate fact_sales INCLUDING cancellations
CREATE TABLE retail.fact_sales AS
SELECT
    r.invoice_no,
    r.stock_code AS product_id,

    -- Normalize customer_id when it is a whole number; otherwise NULL
    CASE
        WHEN r.customer_id IS NOT NULL
         AND r.customer_id = FLOOR(r.customer_id)
        THEN r.customer_id::INTEGER
        ELSE NULL
    END AS customer_id,

    r.invoice_date::DATE AS date_id,
    r.invoice_date,
    r.country,

    r.quantity,
    r.unit_price,

    -- Flags for transparency/auditability in analysis
    (r.invoice_no LIKE 'C%') AS is_canceled,
    (r.quantity < 0)         AS is_return,

    -- Revenue: will be negative for credit notes / returns when priced
    (r.quantity * r.unit_price) AS line_revenue

FROM staging.online_retail_raw r
WHERE r.invoice_no IS NOT NULL
  AND r.invoice_date IS NOT NULL
  AND r.stock_code IS NOT NULL;
  -- IMPORTANT: no longer excluding invoice_no LIKE 'C%'


-- 3) Indexes (safe to re-run)
CREATE INDEX IF NOT EXISTS ix_fact_sales_date     ON retail.fact_sales (date_id);
CREATE INDEX IF NOT EXISTS ix_fact_sales_invoice  ON retail.fact_sales (invoice_no);
CREATE INDEX IF NOT EXISTS ix_fact_sales_product  ON retail.fact_sales (product_id);
CREATE INDEX IF NOT EXISTS ix_fact_sales_customer ON retail.fact_sales (customer_id);

-- 4) Foreign keys (optional but good practice)
ALTER TABLE retail.fact_sales
  ADD CONSTRAINT fk_fact_sales_product
  FOREIGN KEY (product_id) REFERENCES retail.dim_product(product_id);

ALTER TABLE retail.fact_sales
  ADD CONSTRAINT fk_fact_sales_date
  FOREIGN KEY (date_id) REFERENCES retail.dim_date(date_id);

ALTER TABLE retail.fact_sales
  ADD CONSTRAINT fk_fact_sales_customer
  FOREIGN KEY (customer_id) REFERENCES retail.dim_customer(customer_id);

-- ------------------------------------------------------------
-- QA checks (run manually, uncomment if you want)
-- ------------------------------------------------------------
-- SELECT COUNT(*) AS fact_rows FROM retail.fact_sales;
-- SELECT COUNT(*) AS canceled_rows FROM retail.fact_sales WHERE is_canceled = TRUE;
-- SELECT SUM(line_revenue) AS net_revenue FROM retail.fact_sales;
-- SELECT SUM(line_revenue) FILTER (WHERE is_canceled = TRUE) AS canceled_revenue FROM retail.fact_sales;
