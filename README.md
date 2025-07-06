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
The code and explanation of the code is right after this section.
### 📊 Power BI (Visualization)

**In Power BI**, I:
- Created KPIs at the top including:
  1. % change since IPO
  2. Max drawdown
  3. Buy dip win rate
  4. Average of Volume
  5. Best Drop Threshold
  6. Minimum and maximum of close price since IPO
- Created charts for:
  1. Volatility & Risks
  2. Return Insights
  3. Buy-at-Dip Strategy Analysis
- Added slicers and filters for better interaction
(Image for Dashboard is below Data Cleaning)
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

![image](https://github.com/user-attachments/assets/b45bd31f-f011-402e-b6e6-9d049df6e92f)

Looking at the table, we see that if the stock price drops anywhere below 7%, the Win Rate seems to be **unreliable** since the the total cases are too small (fewer or equal to 7).

So, I'll choose drop threshold which have at least 10 cases with Win rates at least 25%:
| Drop %   | Total Cases | Win Rate (%)  |
| -------- | ----------- | ----------    |
| **-2%**  | 49          | 26.53% ✅    | 
| **-3%**  | 38          | 31.58% ✅    |
| **-5%**  | 23          | 26.09% ✅    |
| **-6%**  | 12          | 33.33% ✅    |

Now that we have the Drop Thresholds for different risk tates, then we'll proceed to create BUY SIGNALS.
Buy Signal = 1 => "Yes, we should Buy"
Buy Signal = 0 => "No"

```sql
Create table dbo.BuyDipStrategy (
Date DATE,
Drop_Threshold_Percent INT,
Buy_Signal BIT, -- Should we buy? (if the price drops and the return next day is +2%): 1 = Yes, 0 = No
Rebound_Next_day BIT -- Does it rebound next day? 1 = Yes, 0 = No
-- The logic behind this is to test the Buy Dip Strategy. For example, if you actually buy stocks at the recommended drop thresholds, but it doesn't rebound the next day.
-- Then, the BuyDipStrategy just simply doesn't work.
);

Select *
from dbo.BuyDipStrategy;

Insert into dbo.BuyDipStrategy ([Date],Drop_Threshold_Percent, Buy_Signal, Rebound_Next_day)
Select 
    V.[Date],
    -2 as Drop_Threshold_Percent,
    Case when V.Change_OpenClose*100 <=-2 then 1 else 0 end as Buy_Signal,
    Case 
        when V.Change_OpenClose*100 <=-2 and V.Next_Day_Return*100 >=2 then 1
        when V.Change_OpenClose*100 <=-2 and V.Next_Day_Return*100 <2 then 0
        when V.Change_OpenClose*100 <=-2 and V.Next_Day_Return*100 is null then null
        else null
        end as Rebound_Next_day
from dbo.[VinFast Stock Price History] as V

Union all

Select 
    V.[Date],
    -3 as Drop_Threshold_Percent,
    Case when V.Change_OpenClose*100 <=-3 then 1 else 0 end as Buy_Signal,
    Case 
        when V.Change_OpenClose*100 <=-3 and V.Next_Day_Return*100 >=2 then 1
        when V.Change_OpenClose*100 <=-3 and V.Next_Day_Return*100 <2 then 0
        when V.Change_OpenClose*100 <=-3 and V.Next_Day_Return*100 is null then null
        else null
        end as Rebound_Next_day
from dbo.[VinFast Stock Price History] as V

union all

Select 
    V.[Date],
    -5 as Drop_Threshold_Percent,
    Case when V.Change_OpenClose*100 <=-5 then 1 else 0 end as Buy_Signal,
    Case 
        when V.Change_OpenClose*100 <=-5 and V.Next_Day_Return*100 >=2 then 1
        when V.Change_OpenClose*100 <=-5 and V.Next_Day_Return*100 <2 then 0
        when V.Change_OpenClose*100 <=-5 and V.Next_Day_Return*100 is null then null
        else null
        end as Rebound_Next_day
from dbo.[VinFast Stock Price History] as V

union all

Select 
    V.[Date],
    -6 as Drop_Threshold_Percent,
    Case when V.Change_OpenClose*100 <=-6 then 1 else 0 end as Buy_Signal,
    Case 
        when V.Change_OpenClose*100 <=-6 and V.Next_Day_Return*100 >=2 then 1
        when V.Change_OpenClose*100 <=-6 and V.Next_Day_Return*100 <2 then 0
        when V.Change_OpenClose*100 <=-6 and V.Next_Day_Return*100 is null then null
        else null
        end as Rebound_Next_day
from dbo.[VinFast Stock Price History] as V
;

Alter table dbo.BuyDipStrategy
add [Close] Float,
Next_Day_Return decimal (10,4);

update BDS
set BDS.[Close] = VS.[Close],
    BDS.Next_Day_Return = VS.Next_Day_Return
from dbo.[BuyDipStrategy] as BDS
Join dbo.[VinFast Stock Price History] as VS
        on BDS.[Date] = VS.[Date];
```
Next, I want to test whether retail investors actually win or not if they buy at dip. Winning here means we buy when the stock price drops, and next day, the price goes up at least 2%.
``` sql
Alter table dbo.BuyDipStrategy
add Win_or_not INT; -- If you buy at dip and gain +2%, then 1 = yes, you win. Or else, 0 = No.

update BuyDipStrategy
set Win_or_not =
    case 
    when Buy_Signal = 1 and Rebound_Next_day = 1 then 1
    WHEN Buy_Signal = 1 AND Rebound_Next_day = 0 THEN 0
    else Null
    end
    from BuyDipStrategy;
```
Finally, I want to check the Success Rate of this Buy_Dip_Strategy.
``` sql
SELECT
    Drop_Threshold_Percent,
    SUM(CASE WHEN Buy_Signal = 1 THEN 1 ELSE 0 END) AS Total_Buying_Opportunities, 
    SUM(CASE WHEN Buy_Signal = 1 AND Rebound_Next_day = 1 THEN 1 ELSE 0 END) AS Total_Rebounds,
    ROUND(100.0 * SUM(CASE WHEN Buy_Signal = 1 AND Rebound_Next_day = 1 THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN Buy_Signal = 1 THEN 1 ELSE 0 END), 0),2) AS Success_Rate
    -- Success_Rate = 'Of all the days when the stock dropped enough to trigger a buy, how many times did the price actually go up by at least 2% the next day?'
FROM dbo.BuyDipStrategy
GROUP BY Drop_Threshold_Percent
ORDER BY Drop_Threshold_Percent;
```
#### Behavior by Weekday
I'll create a summary table that includes average daily return, buillish days, and bearish days in Power BI. So first, I need a table for that.  

``` sql
SELECT 
    [Date],
    DATENAME(WEEKDAY, [Date]) AS Weekday_Name,
    Change_OpenClose,
    CASE 
    WHEN Change_OpenClose > 0 THEN 'Bullish' 
    WHEN Change_OpenClose < 0 THEN 'Bearish' 
    else 'Neutral'
    end as Trading_Day_Type
    INTO dbo.Stock_Behavior_Weekday
FROM dbo.[VinFast Stock Price History];
```
#### Monthly KPI

This will help retail investors have a view of the stock's monthly performance.

``` sql
SELECT 
    DATEFROMPARTS(YEAR([Date]), MONTH([Date]), 1) AS [Date],  -- Primary Date column (1st of month). This column is the primary key so that by the time I will have made slicers, they will connect all tables.
    FORMAT([Date], 'yyyy-MM') AS Month_Year,                  -- Display-friendly text
    ROUND(AVG([Close]), 2) AS Avg_Close,
    ROUND(MIN([Close]), 2) AS Min_Close,
    ROUND(MAX([Close]), 2) AS Max_Close,
    ROUND(AVG(Vol), 0) AS Avg_Volume,
    COUNT(*) AS Trading_Days,
    SUM(CASE WHEN Change_OpenClose > 0 THEN 1 ELSE 0 END) AS Gain_Days,
    SUM(CASE WHEN Change_OpenClose < 0 THEN 1 ELSE 0 END) AS Loss_Days
INTO dbo.MonthlyKPI
FROM dbo.[VinFast Stock Price History]
GROUP BY DATEFROMPARTS(YEAR([Date]), MONTH([Date]), 1), FORMAT([Date], 'yyyy-MM');
```
## 📊 Dashboard:
![image](https://github.com/user-attachments/assets/e34ab763-df6f-4c70-a0b5-eeced9255d86)


## 🔍 Insight

Summary:

- VinFast is a highly volatile at first but remained quite weak.
  - It spiked early due to excitement but quickly crashed and hasn’t bounced back.
- Some short-term patterns exist, for example, Tuesdays often show strong gains, especially after losses on Mondays, but long-term investors still face big risks.


## 1. Investor's Concern: “I don’t know when to enter or exit.”

→  What are the optimal entry price to buy and at what price to sell?**

Preferable: Buy low, sell high.

Visuals Used to answer this question:
- Bubble chart: Next Day Return vs Daily % Change

![real one](https://github.com/user-attachments/assets/47929f5d-c34d-40ca-a582-c0ebf8ca37e2)


- Buy-Dip Strategy Table: Success Rate by Drop Level

![image](https://github.com/user-attachments/assets/7773f159-742b-437e-9e54-ca95f4beecc4)

  
- Max and Min Close Price:

![image](https://github.com/user-attachments/assets/73dcdb9a-1c01-4329-8f85-c7b3c4a72d4c)

#### ✅ Entry Strategy (When to Buy)
Rebound is defined as a **≥2% gain the following day**.

**📌 Key Entry Signal:**
- Buy after a **drop between –3% and –5%**
- These drops show a **success rate of ~26–31%** for short-term rebounds

**HOWEVER**, also confirm with: 

- **Spike in trading volume**
  - If price drops with _high volume_ => more people are trading than usual. They are actively reacting to this drop => the price-drop movement can be actually valid.
  - If price drops with _low volume_ => the drop doesn't mean much

- **News or external catalyst**
  - Check with earnings or press releases
  
#### ✅ Exit Strategy (When to Sell)
Most successful rebounds landed in the **+2% to +11% next-day return** zone

**📌 Key Entry Signal:**
- Sell when the stock gains **+2% to +5% the next day**
- Use a **stop-loss of –3% to –5%** to limit downside if trade goes against your plan

#### ⚠️ Limitations of this:
- Strategy does not account for macro news or earnings reports
- Past performance ≠ future guarantee
- **Low success rate (~25%)** suggests this strategy is high-risk without confirmation signals

---
## 2. Investor's Concern: “I need a clearer view of risk.”

→ What’s the volatility, drawdown, and risk-adjusted return profile?**

Visuals Used to answer this question:
- Mark Drawdown Card: -97.06%
- Drawdown from Peak Chart:
![image](https://github.com/user-attachments/assets/b950b4fd-afcf-4899-b4f1-3a9f4acdfeb4)

- Daily Volatility:
![image](https://github.com/user-attachments/assets/f47e20b7-a1c2-4b56-a00b-8dda49fdb693)

- Rolling 7-Day Volatility:
![image](https://github.com/user-attachments/assets/a15cbd13-11e5-4d3c-a1fc-a4dc7c19b9d2)

- Buy-Dip Win Rate Card: 27.06%
--
## 🔻 Max Drawdown: -97.06%

- VinFast has lost **97% of its value** since its highest price.
- If you invested $100 at the top, you'd have less than $3 now.
- It hasn’t bounced back.

## ⚡ Volatility

- Beginning: the price moved up and down **a lot** — up to $30 in a day.
- Now: it barely moves, which could be not much trading or interest anymore.
- Volatility is lower, but the stock still feels unstable at times.


## ❌ Buy-the-Dip Win Rate: 27.06%

- Only 1 in 4 dip-buying attempts have been profitable.
- That means most people who bought after a drop just lost more.

## 🚫 Conclusion

> Vinfast stock has lost most of its value, rarely recovers after drops.
> **Too risky** for most investors — especially beginners or those looking for steady returns.

---
## 3. “I want to know how the stock reacts to events.”
- → How does the stock behave around or key dates?

Visuals Used for this: Daily Change (Open vs Close) Bar Chart

Here're are 3 key dates I picked: 

### 1. 🟢 August 15, 2023 – IPO & First Day Trading
- Why it matters: First exposure to U.S. public markets 

![image](https://github.com/user-attachments/assets/8d80747f-647b-4f6e-8096-2b12ffd767e1)

#### 🧠 Key Interpretation:

| Phase          | What Happened      | What It Means                                        |
| -------------- | ------------------ | ---------------------------------------------------- |
| **Aug 15 - 22**     | IPO Day → +68% and Series of +20% and +90% Gains    | Strong hype and demand                               |
| **Aug 28–Sep** | -20% to -30% drops | The hype didn’t last. The stock quickly reversed, entering a sharp decline. |

> This shows that the stock was being traded mostly on hype and news, not on strong business performance.
>

### 2. 🔴 March 2024 – North Carolina Plant Delayed to 2028
- Why it matters: Raised serious concerns about execution and credibility. Direct hit to growth plans in a key market.

![image](https://github.com/user-attachments/assets/1b43795a-63ba-42da-8d51-f220d050525c)

#### 🧠 Key Interpretation:

| Phase          | What Happened      | What It Means                                        |
| -------------- | ------------------ | ---------------------------------------------------- |
| **Mar 2024**     | Factory delay to 2028 announced    | Negative reaction — confidence dropped, price declined steadily                              |

### 3. 🔵 July 12, 2024 – Q2 Delivery Results + Plant Update
- Why it matters: VinFast released delivery numbers and updated investors on the delayed U.S. factory timeline. After the delayed-plant news, delivery figures affect revenue outlook.

![image](https://github.com/user-attachments/assets/c40af38d-0f0d-4ba7-a274-103b1270417b)

| Phase          | What Happened      | What It Means                                        |
| -------------- | ------------------ | ---------------------------------------------------- |
| **July 12, 2024**     | 📉 No big move   | The market did not react strongly to the delivery numbers or update, suggesting investors were neither interested nor surprised                              |

---
## 4. “I can’t track patterns over time.”

→ What recurring trends or behaviors can I monitor?

Visuals Used to answer this question:
- Weekday Return Bar Chart

![image](https://github.com/user-attachments/assets/7ce822a1-6c91-43b4-b6fd-fcb69ead90f5)

- Monthly KPIs

![image](https://github.com/user-attachments/assets/e2db0717-0ea0-4d49-b6ce-05c688badc65)

- Rolling Volatility & Drawdown Charts

![image](https://github.com/user-attachments/assets/892bd23d-c28e-4435-b112-9cde318fc3e2)

![image](https://github.com/user-attachments/assets/af09fc7f-c1ed-4833-a59c-9d3655a92170)

| Visuals                 | **What It Shows**                                                                                           |
| ------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **📉 Drawdown Chart**     | Stock dropped **over 97%** from its peak and **never recovered**, could be long-term weakness.                      |
| **📊 Weekday Return**     | Tuesdays often surge, especially after red Mondays, which is a potential short-term pattern.                        |
| **📅 Monthly KPIs**       | Since late 2023, most months have **more down days** than up, which showing consistent bearish force, in order words, selling pressure.         |
| **📈 Rolling Volatility** | Volatility was extreme after IPO, but **cooled off** despite occasional spikes |
