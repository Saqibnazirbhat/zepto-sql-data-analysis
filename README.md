# 🛒 Zepto E-commerce Inventory — SQL Data Analysis

<p align="center">
  <img src="https://img.shields.io/badge/PostgreSQL-12%2B-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/SQL-Analytics-CC2927?style=for-the-badge&logo=databricks&logoColor=white" alt="SQL"/>
  <img src="https://img.shields.io/badge/Dataset-Kaggle-20BEFF?style=for-the-badge&logo=kaggle&logoColor=white" alt="Kaggle"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License"/>
</p>

> An end-to-end SQL analytics project on a real-world e-commerce inventory dataset covering database design, exploratory analysis, data cleaning, and **business-driven queries** using joins, CTEs, window functions, and indexing.

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Tech Stack](#-tech-stack)
- [Dataset](#-dataset)
- [Database Schema](#-database-schema)
- [Project Workflow](#-project-workflow)
- [SQL Techniques Demonstrated](#-sql-techniques-demonstrated)
- [Business Questions Answered](#-business-questions-answered)
- [How to Run](#-how-to-run)
- [Engineering Notes & Best Practices](#-engineering-notes--best-practices)
- [Author](#-author)
- [License](#-license)

---

## 🎯 Overview

This project simulates how a data analyst works behind the scenes at a quick-commerce company. Starting from a **messy, real-world inventory dataset**, it walks through the complete analytics lifecycle in PostgreSQL:

✅ Design a clean relational schema for raw SKU-level inventory data
✅ Perform **Exploratory Data Analysis (EDA)** on categories, stock, and pricing
✅ **Clean the data** — handle nulls, remove invalid rows, fix pricing units (paise → ₹)
✅ Answer **business questions** on pricing, revenue, stock availability, and value-for-money
✅ Apply **performance best practices** — indexing, window functions, CTEs, and readable, maintainable SQL

The script is structured as a single, well-documented file that reads top-to-bottom as an analyst's workflow.

---

## 🧰 Tech Stack

| Tool | Purpose |
|------|---------|
| **PostgreSQL 12+** | Relational database & query engine |
| **SQL** | Schema design, EDA, cleaning, analysis |
| **pgAdmin / psql** | Client for running the script and importing data |

---

## 📁 Dataset

Each row represents a unique **SKU** (Stock Keeping Unit). Duplicate product names are expected — the same product appears in different pack sizes, weights, or discounts, exactly like a real catalogue.

📦 **Source:** [Zepto Inventory Dataset on Kaggle](https://www.kaggle.com/datasets/palvinder2006/zepto-inventory-dataset/data?select=zepto_v2.csv) (~3.7k rows)

| Column | Description |
|--------|-------------|
| `sku_id` | Synthetic primary key — unique per product entry |
| `name` | Product name as shown on the app |
| `category` | Product category (Fruits, Snacks, Beverages, …) |
| `mrp` | Maximum Retail Price (converted from paise to ₹) |
| `discount_percent` | Discount applied on MRP |
| `discounted_selling_price` | Final price after discount (in ₹) |
| `available_quantity` | Units available in inventory |
| `weight_in_gms` | Product weight in grams |
| `out_of_stock` | Boolean stock-availability flag |
| `quantity` | Units per package |

---

## 🗄️ Database Schema

```sql
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
```

> **Naming note:** columns use `snake_case`. PostgreSQL folds unquoted identifiers to lowercase, so camelCase names like `discountPercent` silently become `discountpercent` (or force you to quote them everywhere) — `snake_case` avoids that footgun.

---

## 🔧 Project Workflow

| Stage | What happens |
|-------|--------------|
| **1. Schema** | Create a permissive staging table sized for the raw scraped data |
| **2. Import** | Load `zepto_v2.csv` via `\copy` (psql) or pgAdmin's Import dialog |
| **3. Exploration** | Row counts, sample rows, null checks, distinct categories, stock split, duplicate SKUs |
| **4. Cleaning** | Inspect & remove invalid pricing rows; convert MRP & selling price from paise to ₹ |
| **5. Indexing** | Add indexes (incl. a partial index) that support the analytical queries |
| **6. Analysis** | Answer 8 business questions with clean, optimized SQL |

---

## 🧠 SQL Techniques Demonstrated

This project is intentionally written to showcase modern, production-minded SQL:

- 🪟 **Window functions** — `SUM(...) OVER ()` for each category's *share of total revenue*; `COUNT(*) OVER ()` for each stock group's *share of the catalogue*.
- 🧩 **CTEs** — bucketing logic defined once and reused for grouped aggregation.
- 🗂️ **Indexing** — B-tree indexes plus a **partial index** (`WHERE NOT out_of_stock`) targeting the most common analytical filter.
- 🧮 **Aggregation & grouping** — `GROUP BY`, `HAVING`, conditional `CASE` bucketing.
- ✨ **Clean conventions** — `snake_case`, UPPERCASE keywords, aligned clauses, sectioned & commented script.

---

## ❓ Business Questions Answered

1. **Top 10 best-value products** by discount percentage
2. **High-MRP products (> ₹300)** that are currently **out of stock**
3. **Estimated revenue per category** — with each category's *share of total revenue*
4. **Premium products** (MRP > ₹500) carrying a **low discount** (< 10%)
5. **Top 5 categories** by **average discount percentage**
6. **Best value-for-money** products by **price per gram**
7. **Products bucketed by weight** into Low / Medium / Bulk (+ SKU count per band)
8. **Total inventory weight per category**

---

## ▶️ How to Run

1. **Clone the repository**
   ```bash
   git clone https://github.com/Saqibnazirbhat/zepto-sql-data-analysis.git
   cd zepto-sql-data-analysis
   ```

2. **Create a database** in PostgreSQL and open `Zepto_SQL_data_analysis.sql`.

3. **Import the dataset** — either via pgAdmin's Import dialog, or with psql:
   ```sql
   \copy zepto (category, name, mrp, discount_percent, available_quantity,
                discounted_selling_price, weight_in_gms, out_of_stock, quantity)
   FROM 'zepto_v2.csv'
   WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');
   ```
   > The column list is explicit, so the load is driven by **column order** — the camelCase CSV header maps cleanly onto the snake_case table columns. If you hit an encoding error, re-save the CSV as **CSV UTF-8**.

4. **Run the script top-to-bottom** to reproduce the full analysis.

---

## ⚙️ Engineering Notes & Best Practices

**Smarter query patterns**
- Window functions add context in a single pass — share-of-total metrics without extra round-trips.
- A CTE keeps the weight-band logic defined once and reused.
- "Top / highest" queries are sorted `DESC` so headline rows appear first.

**Indexing (illustrative at this scale)**
- `category` and `discount_percent DESC` support the grouping and ranking queries.
- A **partial index** `(category) WHERE NOT out_of_stock` targets stock/revenue questions that only consider available SKUs.
- At ~3.7k rows PostgreSQL sensibly prefers sequential scans; these indexes show what pays off as the table grows. Always build indexes **after** the bulk load.

**Data integrity (production hardening)**
- `zepto` is deliberately a permissive **staging table** — scraped data is validated *after* loading. In production you'd promote clean rows into a typed table with constraints such as:
  ```sql
  CHECK (mrp >= 0),
  CHECK (discount_percent BETWEEN 0 AND 100),
  CHECK (discounted_selling_price <= mrp)
  ```
- The paise→rupees `UPDATE` must run **exactly once**. A robust pipeline would store raw paise and expose rupees as a generated/derived column.

---

## 👨‍💻 Author

**Saqib Nazir Bhat**
🔗 GitHub: [@Saqibnazirbhat](https://github.com/Saqibnazirbhat)

If you found this project useful, please consider giving it a ⭐ — it helps a lot!

---

## 📜 License

Released under the **MIT License** — free to fork, star, and use in your own portfolio.
