# 📈 VinFast Stock Analysis Dashboard (IPO to June 2025)

This project helps retail investors understand patterns, risks, and simple trading strategies — going beyond what websites like Yahoo Finance show.

---

## 🎯 Purpose

Many investors struggle with knowing **when to buy or sell**, understanding **how risky** a stock is, or seeing how a stock **behaves after big events**. This data project helps answer those questions using real data.

---

## 💼 Business Questions This Dashboard Answers

- When is the best time to buy or sell VinFast stock?
- How does VinFast usually behave after a big drop?
- Are certain weekdays or months more bullish or bearish?
- What happens after high trading volume days?
- How risky is the stock right now compared to before?
- What if I had followed a simple buy-sell strategy — would it work?

---
## 🎯 Scope:

This project focuses on:

- **VinFast Auto Ltd. stock data** from **August 15, 2023 (IPO)** to **June 28, 2025**.  
- Data File (downloaded from Investing.com:  
  `vinfast_stock_price.csv` *(original columns: Date, Open, High, Low, Close, Adj Close, Volume, Change)*

- Analysis segmented by:
  - **Date ranges** (daily, weekly, monthly summaries)
  - **Price behavior** (Open, Close, High, Low, Adjusted Close)
  - **Trading volume** (converted from K/M format to full numeric values)
  - **Percentage change** (cleaned from string format to decimal)
  - **Volatility and drawdowns**
  - **Bullish vs. bearish days**
  - **Event-based reactions** (e.g., earnings, IPO drop, sudden spikes)
  - **Simple backtesting rules** (e.g., buy after drop > X%, sell after gain > Y%)

  
## 🧰 Tools & Methodology

### 🛠 SQL Server (Data Cleaning)

**In SQL Server**, I:
- Converted volume (text, like `"681.45K"`) and change (text, like `"−1.23%"`) to decimal numbers
- Added new columns like numeric volume and percent change for analysis

### 📊 Power BI (Visualization)

**In Power BI**, I:
- Created charts for price trends, volume, and volatility
- Added slicers and filters for better interaction
- Built summaries like:
  - Monthly price behavior
  - Bullish vs. bearish day counts
  - Drawdown and recovery charts
  - Simple strategy backtesting (e.g., buy on big dip, sell on small rise)

---
## 🧼 Data Cleaning (SQL Code)
##### 0. Check the structure (columns, data types, nullability)
```sql
EXEC sp_help [VinFast Stock Price History];
```
the table is already pretty much cleaned but the **Vol** and **Change** is stored as `"nvarchar(50)"`, which is used to stored text (string).
##### => Convert Vol and Change to numeric values.

Here are the steps:
##### 1. Add new numeric columns
> Explain: If you change directly on the original column, casting them in-place will either fail or give incorrect results. it's better to create new numeric columns (Vol_num, Change_num), convert values there safely, and then drop the original ones and rename the new columns later.
>

The code:
```sql
ALTER TABLE dbo.[VinFast Stock Price History]
    ADD Vol_num DECIMAL(18, 2),
        Change_num DECIMAL(10, 4);
```
##### 2. Convert Volume (e.g., 543.81K or 1.2M) to numeric

```sql
Update dbo.[VinFast Stock Price History]
set Vol_num = 
    Case 
        When Vol like '%K' then TRY_CAST(replace(Vol, 'K', '') as decimal(18, 2))*1000
        When Vol like '%M' then TRY_CAST(replace(Vol, 'M', '') as decimal(18, 2))*1000000
        else TRY_CAST (Vol as Decimal(18, 2))
    End;
```
##### 3. Store the original Vol, Change as Backup
```sql
    SELECT Date, Vol, Change
    INTO Vol_Change_Backup
    FROM dbo.[VinFast Stock Price History];
```

##### 4. Convert Change (e.g., 0.00% ) to numeric

```sql
Update dbo.[VinFast Stock Price History]
set Change_num = try_cast(replace(Change, '%', '') as DECIMAL(10,4))/100
WHERE Change like '%[0-9]%[%]'
```
##### 5. Drop the old columns and rename the new ones:

```sql
    alter table dbo.[VinFast Stock Price History]
    drop column Vol, Change;

    EXEC sp_rename 'dbo.[VinFast Stock Price History].Vol_num', 'Vol', 'COLUMN';
    EXEC sp_rename 'dbo.[VinFast Stock Price History].Change_num', 'Change', 'COLUMN';
```

## 🔍 What Makes This Different from Yahoo Finance?

Unlike stock sites that only show prices and charts, this dashboard adds insights like:
- Stock behavior by **day of week** or **month**
- **Rolling volatility** and recovery time after a drop
- Reactions to **news or events**
- What would happen if you followed a simple trading rule
- Summarized trends and strategy outcomes over time

---

## 📁 Folder Structure
VinFast-Stock-Dashboard/
│
├── sql/
│ └── vinfast_cleaning.sql # SQL script to clean raw data
├── pbix/
│ └── vinfast_dashboard.pbix # Power BI dashboard file
├── data/
│ └── vinfast_raw.csv # Original CSV file (optional)
├── screenshots/
│ └── preview.png # Dashboard preview image
└── README.md # You're here!

