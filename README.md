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

- **VinFast Auto Ltd. stock data** from **August 14, 2023 (IPO)** to **June 27, 2025**.  
- Data File (downloaded from Investing.com:  
  [VinFast Stock Price History.csv](https://github.com/ThaoKine/Vinfast-Stock-Performance/blob/main/VinFast%20Stock%20Price%20History.csv) *(original columns: Date, Open, High, Low, Close, Adj Close, Volume, Change)*

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

### 🛠 SQL Server (Data Cleaning & Analysis) 
The code is right after this section.
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
#### 1. Add new numeric columns
> Explain: If you change directly on the original column, casting them in-place will either fail or give incorrect results. it's better to create new numeric columns (Vol_num, Change_num), convert values there safely, and then drop the original ones and rename the new columns later.
>

The code:
```sql
ALTER TABLE dbo.[VinFast Stock Price History]
    ADD Vol_num DECIMAL(18, 2),
        Change_num DECIMAL(10, 4);
```
#### 2. Convert Volume (e.g., 543.81K or 1.2M) to numeric

```sql
Update dbo.[VinFast Stock Price History]
set Vol_num = 
    Case 
        When Vol like '%K' then TRY_CAST(replace(Vol, 'K', '') as decimal(18, 2))*1000
        When Vol like '%M' then TRY_CAST(replace(Vol, 'M', '') as decimal(18, 2))*1000000
        else TRY_CAST (Vol as Decimal(18, 2))
    End;
```
#### 3. Store the original Vol, Change as Backup
```sql
    SELECT Date, Vol, Change
    INTO Vol_Change_Backup
    FROM dbo.[VinFast Stock Price History];
```

#### 4. Convert Change (e.g., 0.00% ) to numeric

```sql
Update dbo.[VinFast Stock Price History]
set Change_num = try_cast(replace(Change, '%', '') as DECIMAL(10,4))/100
WHERE Change like '%[0-9]%[%]'
```
#### 5. Drop the old columns and rename the new ones:

```sql
    alter table dbo.[VinFast Stock Price History]
    drop column Vol, Change;

    EXEC sp_rename 'dbo.[VinFast Stock Price History].Vol_num', 'Vol', 'COLUMN';
    EXEC sp_rename 'dbo.[VinFast Stock Price History].Change_num', 'Change', 'COLUMN';
```
## 👮‍♀️ Data Analysis (SQL Code)

#### 1. Calculate the Volatility (High - Low)**
```sql
Alter table dbo.[VinFast Stock Price History]
alter column High decimal (10,4); -- the original data type for High is float so I wanna change it.

Alter table dbo.[VinFast Stock Price History]
alter column Low decimal (10,4); -- the original data type for High is float so I wanna change it.

Alter table dbo.[VinFast Stock Price History]
add Volatility decimal (10,4); 

Update dbo.[VinFast Stock Price History]
    set Volatility = 
        case 
            when High is not null and Low is not null
            then High - Low
            else Null
        end;
```
#### 2. Calculate the Rolling 7-day Volatility (Standard Deviation)
Explanation: this is to measure how crazy the stock price has moving up and down the past 7 days.
- 📈 High rolling volatility = Price is moving a lot — risky or unstable
- 📉 Low rolling volatility = Price is steady — more stable
- Formula: 7-Day Volatility = STDEV(Daily Return from today and previous 6 days)

```sql
EXEC sp_rename 'dbo.[VinFast Stock Price History].Daily Return', 'Daily_Return', 'COLUMN'; -- I feel like the Change in the orginal column is calculated like Daily_Return, so I rename it.
alter table dbo.[VinFast Stock Price History]
add Rolling_volatility_7D Decimal (10,6); -- column names can’t start with a number unless you put them in square brackets.

UPDATE V
SET Rolling_Volatility_7D = R.RollingStdDev
FROM dbo.[VinFast Stock Price History] AS V
CROSS APPLY ( -- CROSS APPLY is used to apply a subquery for each row in the table.
    SELECT 
        CASE 
            WHEN COUNT(*) = 7 THEN STDEV(W.Daily_Return) -- the condition to restrict the calculation to only 7 existing trading days 
            ELSE NULL -- if not, it should be NULL to prevent using INCOMPLETE data
        END AS RollingStdDev
    FROM (
        SELECT TOP 7 W.Daily_Return -- Get the 7 most recent trading days (including current row's date).
        FROM dbo.[VinFast Stock Price History] AS W
        WHERE W.[Date] <= V.[Date]
        ORDER BY W.[Date] DESC
    ) AS W
) AS R;
```
#### 3. Daily % Change (Close vs Open)
Explanation: This helps retail investors to know which days are bulish and bearish.
```sql
EXEC sp_rename 'dbo.[VinFast Stock Price History].Price', 'Close', 'COLUMN'; -- 'Price' can be confusing sometimes to me (like what price is it referred to?), so I change it to Close. 

alter table dbo.[VinFast Stock Price History]
add Change_OpenClose Decimal (10, 4);

Update dbo.[VinFast Stock Price History]
    set Change_OpenClose = 
        case 
            when [Open] is not null and [Close] is not null
            then cast(([Close]-[Open])/[Open] as Decimal (10, 4)) 
            -- CAST(... AS DECIMAL(10,4)) ensures the result fits Change_OpenClose's data type.
            else Null
        end;
```
#### 4. Drawdown from Peak
Explanation: Drawdown = 'How much the stock has fallen from its highest price so far?'
It helps retail investors answer three key questions:
- 1. “How bad was the worst dip?”
- 2. “How long did it take to recover?”
- 3. “When should I have sold to avoid losses?”

```sql
alter table dbo.[VinFast Stock Price History]
add Peak_Drawdown Decimal (10,4);

UPDATE V
SET Peak_Drawdown = 
    TRY_CAST ((V.[Close] - P.Peak)*1.0/P.Peak as Decimal (10,4))
FROM dbo.[VinFast Stock Price History] AS V
CROSS APPLY ( -- CROSS APPLY is used to apply a subquery for each row in the table.
    SELECT 
        Max(W.[Close]) as Peak
        FROM dbo.[VinFast Stock Price History] AS W
        WHERE W.[Date] <= V.[Date]
) AS P;
```
#### 5. Next day return
This helps retail investors know what happened after a spike/drop (if there was a spike/drop) and if we know how the stock behaved after such events, we can predict when to buy and when to sell that can earn a big profit for us.

``` sql
alter table dbo.[VinFast Stock Price History]
add Next_Day_Return Decimal (10,4);

Update V
    set Next_Day_Return = try_cast((Next.[Close]-V.[Close])*1.0/V.[Close] as Decimal (10, 4)) 
    from dbo.[VinFast Stock Price History] as V
    join dbo.[VinFast Stock Price History] as Next
        on Next.[Date] = DATEADD(Day, 1, V.[Date]); -- This worked but didn't return the correct result since stock is not traded on weekends/holidays. and DATEADD syntax only add calendar days.

    -- => we'll use LEAD() window function since it only cares about the next row's value instead of the date.
    -- I'll use a CTE for this:

    With whatever as (
    Select 
    [Date],
    [Close],
    LEAD ([Close]) OVER (order by [Date]) as Next_Close -- Remember: LEAD () OVER. NOT LEAD (.. OVER). 
    from dbo.[VinFast Stock Price History]
    )
    Update V -- do not up Update CTE in SQL Server since it's not allowed. So Update the original table and JOIN the original table with CTE.
    set Next_Day_Return = TRY_CAST ((Next_Close - V.[Close])*1.0/V.[Close] as Decimal(10,4))
    from dbo.[VinFast Stock Price History] as V
    Join whatever
    on V.[Date] = whatever.[Date]
    ;
    -- There was a NULL in 2025-06-27, which is the last row in your table => NULL for Next_Day_Return for this row. Moreover, LEAD() can’t find “tomorrow” (2025-06-28) because there’s no data for the next day.
```
#### 6. Buy-the-Dip Strategy
Explanation: Usually, retail investors buy stocks when their prices dropped a lot. But: 
1. Will the price go up again? And when? In other words, how do we know that it will go up? 
2. How many times that it actually goes up? (Since we want to spot a pattern here, not just some random chance)
   
So in this section, we will determine the drop thredshold that is actually associated with rebound the next day. So to me, I choose rebound level at least **2%**.
And then, I'll calculate the frequency of the rebound, i.e, "How often a stock rebounded 2%+ the next day after dropping around X% today?"
Based on the frequency of the rebound, we can also calculate the Success_rate = (Frequency of rebound/Total Cases)

Step 1: Find the drop thresholds
```sql
WITH Drops_CTE AS (
    SELECT 
        FLOOR(Change_OpenClose*100.0) AS Drop_Threshold_Percent,
        Next_Day_Return
    FROM dbo.[VinFast Stock Price History]
    WHERE Change_OpenClose < 0
)

SELECT 
    Drop_Threshold_Percent,
    COUNT(*) AS Total_Cases,
    SUM(CASE WHEN Next_Day_Return >= 0.02 THEN 1 ELSE 0 END) AS Rebound_Frequency,
    ROUND(
        100.0 * 
        SUM(CASE WHEN Next_Day_Return >= 0.02 THEN 1 ELSE 0 END) * 1.0 / 
        COUNT(*),
        2
    ) AS Win_Rate
FROM Drops_CTE
GROUP BY Drop_Threshold_Percent
ORDER BY Drop_Threshold_Percent;
```
And this is illustration of this:
![image](https://github.com/user-attachments/assets/dbf2f807-f82a-49a3-893f-ce5f4266cfe4)



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

