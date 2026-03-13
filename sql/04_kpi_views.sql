-- ==================================================
-- 04_kpi_views.sql
-- Project: Retail Revenue Optimization (Online Retail II - UCI)
-- Database: PostgreSQL
--
-- Purpose
--   Create business-facing KPI views for reporting and Power BI.
--
-- Notes
--   - retail.fact_sales already excludes canceled invoices
--   - Returns remain (quantity < 0), so "net" metrics reflect returns
--   - Where useful, we provide both NET and GROSS variants
-- ==================================================

CREATE SCHEMA IF NOT EXISTS retail;


-- --------------------------------------------------
-- 1) Overall KPIs (NET)
--    - Net revenue includes returns (negative line_revenue)
--    - Orders count distinct invoice_no
--    - AOV = net_revenue / orders
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_kpi_overall_net AS
SELECT
    SUM(line_revenue) AS net_revenue,
    COUNT(DISTINCT invoice_no) AS orders,
    CASE
        WHEN COUNT(DISTINCT invoice_no) = 0 THEN NULL
        ELSE SUM(line_revenue) / COUNT(DISTINCT invoice_no)
    END AS aov_net,
    SUM(CASE WHEN is_return THEN line_revenue ELSE 0 END) AS returns_revenue_net
FROM retail.fact_sales;

-- Name Change for clarity:
ALTER VIEW retail.v_kpi_overall_net
RENAME COLUMN returns_revenue_net TO negative_revenue_impact;

-- --------------------------------------------------
-- 2) Overall KPIs (GROSS)
--    - Excludes returns so you can compare gross vs net
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_kpi_overall_gross AS
SELECT
    SUM(line_revenue) AS gross_revenue,
    COUNT(DISTINCT invoice_no) AS orders,
    CASE
        WHEN COUNT(DISTINCT invoice_no) = 0 THEN NULL
        ELSE SUM(line_revenue) / COUNT(DISTINCT invoice_no)
    END AS aov_gross
FROM retail.fact_sales
WHERE is_return = FALSE;


-- --------------------------------------------------
-- 3) Monthly KPI trend (NET)
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_kpi_monthly_net AS
SELECT
    d.year_month,
    MIN(d.date_id) AS month_start_date,
    SUM(f.line_revenue) AS net_revenue,
    COUNT(DISTINCT f.invoice_no) AS orders,
    CASE
        WHEN COUNT(DISTINCT f.invoice_no) = 0 THEN NULL
        ELSE SUM(f.line_revenue) / COUNT(DISTINCT f.invoice_no)
    END AS aov_net
FROM retail.fact_sales f
JOIN retail.dim_date d
  ON d.date_id = f.date_id
GROUP BY d.year_month
ORDER BY d.year_month;


-- --------------------------------------------------
-- 4) Daily KPI trend (NET)
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_kpi_daily_net AS
SELECT
    f.date_id,
    SUM(f.line_revenue) AS net_revenue,
    COUNT(DISTINCT f.invoice_no) AS orders,
    CASE
        WHEN COUNT(DISTINCT f.invoice_no) = 0 THEN NULL
        ELSE SUM(f.line_revenue) / COUNT(DISTINCT f.invoice_no)
    END AS aov_net
FROM retail.fact_sales f
GROUP BY f.date_id
ORDER BY f.date_id;


-- --------------------------------------------------
-- 5) Product performance (NET)
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_product_performance_net AS
SELECT
    f.product_id,
    p.product_description,
    SUM(f.line_revenue) AS net_revenue,
    SUM(f.quantity) AS units_net,
    COUNT(DISTINCT f.invoice_no) AS invoices_count
FROM retail.fact_sales f
JOIN retail.dim_product p
  ON p.product_id = f.product_id
GROUP BY f.product_id, p.product_description
ORDER BY net_revenue DESC;


-- --------------------------------------------------
-- 6) Country performance (NET)
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_country_performance_net AS
SELECT
    COALESCE(f.country, 'Unknown') AS country,
    SUM(f.line_revenue) AS net_revenue,
    COUNT(DISTINCT f.invoice_no) AS orders,
    CASE
        WHEN COUNT(DISTINCT f.invoice_no) = 0 THEN NULL
        ELSE SUM(f.line_revenue) / COUNT(DISTINCT f.invoice_no)
    END AS aov_net
FROM retail.fact_sales f
GROUP BY COALESCE(f.country, 'Unknown')
ORDER BY net_revenue DESC;


-- --------------------------------------------------
-- 7) Customer order counts (for retention / repeat proxy)
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_customer_orders AS
SELECT
    f.customer_id,
    COUNT(DISTINCT f.invoice_no) AS order_count,
    MIN(f.date_id) AS first_order_date,
    MAX(f.date_id) AS last_order_date,
    SUM(f.line_revenue) AS net_revenue
FROM retail.fact_sales f
WHERE f.customer_id IS NOT NULL
GROUP BY f.customer_id;


-- --------------------------------------------------
-- 8) Returning customer rate (simple proxy)
-- Definition:
--   returning = customer has 2+ distinct orders (in fact_sales)
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_kpi_returning_customer_rate AS
WITH per_cust AS (
    SELECT
        customer_id,
        order_count
    FROM retail.v_customer_orders
)
SELECT
    COUNT(*) FILTER (WHERE order_count >= 2) AS returning_customers,
    COUNT(*) AS tracked_customers,
    (COUNT(*) FILTER (WHERE order_count >= 2))::NUMERIC / NULLIF(COUNT(*), 0) AS returning_customer_rate
FROM per_cust;


-- --------------------------------------------------
-- 9) QA view: quick row count snapshot (optional, helpful)
-- --------------------------------------------------
CREATE OR REPLACE VIEW retail.v_qa_row_counts AS
SELECT
    (SELECT COUNT(*) FROM staging.online_retail_raw) AS staging_rows,
    (SELECT COUNT(*) FROM retail.fact_sales)         AS fact_rows,
    (SELECT COUNT(*) FROM retail.dim_product)        AS dim_product_rows,
    (SELECT COUNT(*) FROM retail.dim_customer)       AS dim_customer_rows,
    (SELECT COUNT(*) FROM retail.dim_date)           AS dim_date_rows;


SELECT * FROM retail.v_kpi_overall_net;
SELECT * FROM retail.v_kpi_monthly_net LIMIT 5;
SELECT * FROM retail.v_kpi_returning_customer_rate;
SELECT * FROM retail.v_qa_row_counts;


SELECT
  COUNT(*) FILTER (WHERE is_canceled = TRUE) AS canceled_rows,
  SUM(line_revenue) FILTER (WHERE is_canceled = TRUE) AS canceled_revenue
FROM retail.fact_sales;


SELECT * FROM retail.v_kpi_overall_net;
