/* =============================================================================
   Zepto E-commerce Inventory  —  SQL Data Analysis
   -----------------------------------------------------------------------------
   Dataset : Zepto product catalogue, one row per SKU (~3.7k rows)
   Engine  : PostgreSQL 12+
   Layout  : 1. Schema definition
             2. Data import
             3. Data exploration (EDA)
             4. Data cleaning
             5. Indexing
             6. Business analysis

   Conventions
     - snake_case identifiers (unquoted identifiers are folded to lowercase in
       PostgreSQL, so camelCase names are a silent footgun — avoid them).
     - Keywords UPPERCASE, identifiers lowercase, clauses aligned for scanning.
   ============================================================================ */


/* -----------------------------------------------------------------------------
   1. Schema definition
   The table is intentionally permissive (few NOT NULLs, no CHECK constraints):
   it is a raw landing/staging table for scraped data that is validated and
   cleaned *after* loading. See the README for production-hardening notes.
   ----------------------------------------------------------------------------- */
DROP TABLE IF EXISTS zepto;

CREATE TABLE zepto (
    sku_id                   SERIAL PRIMARY KEY,
    category                 VARCHAR(120),
    name                     VARCHAR(150) NOT NULL,
    mrp                      NUMERIC(8,2),
    discount_percent         NUMERIC(5,2),
    available_quantity       INTEGER,
    discounted_selling_price NUMERIC(8,2),
    weight_in_gms            INTEGER,
    out_of_stock             BOOLEAN,
    quantity                 INTEGER
);


/* -----------------------------------------------------------------------------
   2. Data import
   Run the line below in psql (it is a psql meta-command, not plain SQL, so it
   will not run inside the pgAdmin query tool — use pgAdmin's Import dialog
   there). Columns are listed explicitly: the load is driven by column ORDER,
   so the camelCase CSV header maps cleanly onto our snake_case columns.

   \copy zepto (category, name, mrp, discount_percent, available_quantity,
                discounted_selling_price, weight_in_gms, out_of_stock, quantity)
   FROM 'data/zepto_v2.csv'
   WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');
   ----------------------------------------------------------------------------- */


/* -----------------------------------------------------------------------------
   3. Data exploration (EDA)
   ----------------------------------------------------------------------------- */

-- Total number of rows
SELECT COUNT(*) AS total_rows
FROM zepto;

-- Sample of the data
SELECT *
FROM zepto
LIMIT 10;

-- Rows with a NULL in any analytically relevant column
SELECT *
FROM zepto
WHERE category                 IS NULL
   OR name                     IS NULL
   OR mrp                      IS NULL
   OR discount_percent         IS NULL
   OR available_quantity       IS NULL
   OR discounted_selling_price IS NULL
   OR weight_in_gms            IS NULL
   OR out_of_stock             IS NULL
   OR quantity                 IS NULL;

-- Distinct product categories
SELECT DISTINCT category
FROM zepto
ORDER BY category;

-- In-stock vs out-of-stock SKUs, with each group's share of the catalogue
SELECT
    out_of_stock,
    COUNT(*)                                          AS sku_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_catalogue
FROM zepto
GROUP BY out_of_stock
ORDER BY out_of_stock;

-- Product names that map to more than one SKU (same product, different packs)
SELECT
    name,
    COUNT(*) AS sku_count
FROM zepto
GROUP BY name
HAVING COUNT(*) > 1
ORDER BY sku_count DESC, name;


/* -----------------------------------------------------------------------------
   4. Data cleaning
   ----------------------------------------------------------------------------- */

-- Inspect rows with non-positive pricing before deleting anything
SELECT *
FROM zepto
WHERE mrp = 0
   OR discounted_selling_price = 0;

-- Remove invalid catalogue entries that have no MRP
DELETE FROM zepto
WHERE mrp = 0;

-- Prices were scraped in paise; convert MRP and selling price to rupees.
-- NOTE: run exactly once — re-running divides the values by 100 again.
UPDATE zepto
SET mrp                      = mrp / 100.0,
    discounted_selling_price = discounted_selling_price / 100.0;

-- Spot-check the converted prices
SELECT mrp, discounted_selling_price
FROM zepto
LIMIT 10;


/* -----------------------------------------------------------------------------
   5. Indexing
   At ~3.7k rows PostgreSQL will (correctly) prefer sequential scans, so these
   are illustrative of what would benefit this workload at production scale.
   Build them *after* the load/clean steps so the bulk write stays fast.
   ----------------------------------------------------------------------------- */
CREATE INDEX IF NOT EXISTS idx_zepto_category     ON zepto (category);
CREATE INDEX IF NOT EXISTS idx_zepto_discount     ON zepto (discount_percent DESC);
-- Partial index: most stock/revenue questions only look at available SKUs
CREATE INDEX IF NOT EXISTS idx_zepto_in_stock_cat ON zepto (category) WHERE NOT out_of_stock;


/* -----------------------------------------------------------------------------
   6. Business analysis
   ----------------------------------------------------------------------------- */

-- Q1. Top 10 best-value products by discount percentage
SELECT DISTINCT
    name,
    mrp,
    discount_percent
FROM zepto
ORDER BY discount_percent DESC
LIMIT 10;

-- Q2. High-MRP products (> ₹300) that are currently out of stock
SELECT DISTINCT
    name,
    mrp
FROM zepto
WHERE out_of_stock
  AND mrp > 300
ORDER BY mrp DESC;

-- Q3. Estimated revenue per category, plus each category's share of the total.
--     SUM(SUM(...)) OVER () is a window over the grouped rows = grand total.
SELECT
    category,
    SUM(discounted_selling_price * available_quantity) AS estimated_revenue,
    ROUND(
        100.0 * SUM(discounted_selling_price * available_quantity)
              / SUM(SUM(discounted_selling_price * available_quantity)) OVER (),
        2
    ) AS revenue_share_pct
FROM zepto
GROUP BY category
ORDER BY estimated_revenue DESC;

-- Q4. Premium products (MRP > ₹500) carrying a low discount (< 10%)
SELECT DISTINCT
    name,
    mrp,
    discount_percent
FROM zepto
WHERE mrp > 500
  AND discount_percent < 10
ORDER BY mrp DESC, discount_percent DESC;

-- Q5. Top 5 categories by average discount percentage
SELECT
    category,
    ROUND(AVG(discount_percent), 2) AS avg_discount_percent,
    COUNT(*)                        AS sku_count
FROM zepto
GROUP BY category
ORDER BY avg_discount_percent DESC
LIMIT 5;

-- Q6. Best value-for-money products by price per gram (weight >= 100g)
SELECT DISTINCT
    name,
    weight_in_gms,
    discounted_selling_price,
    ROUND(discounted_selling_price / weight_in_gms, 2) AS price_per_gram
FROM zepto
WHERE weight_in_gms >= 100
ORDER BY price_per_gram;

-- Q7. Classify products into weight bands
SELECT DISTINCT
    name,
    weight_in_gms,
    CASE
        WHEN weight_in_gms < 1000 THEN 'Low'
        WHEN weight_in_gms < 5000 THEN 'Medium'
        ELSE 'Bulk'
    END AS weight_band
FROM zepto
ORDER BY weight_in_gms;

-- Q7b. SKU count per weight band (CTE keeps the bucketing logic defined once)
WITH banded AS (
    SELECT
        sku_id,
        CASE
            WHEN weight_in_gms < 1000 THEN 'Low'
            WHEN weight_in_gms < 5000 THEN 'Medium'
            ELSE 'Bulk'
        END AS weight_band
    FROM zepto
)
SELECT
    weight_band,
    COUNT(*) AS sku_count
FROM banded
GROUP BY weight_band
ORDER BY sku_count DESC;

-- Q8. Total inventory weight per category
SELECT
    category,
    SUM(weight_in_gms * available_quantity) AS total_weight_gms
FROM zepto
GROUP BY category
ORDER BY total_weight_gms DESC;
