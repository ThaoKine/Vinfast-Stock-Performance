Select *
from dbo.[VinFast Stock Price History];

EXEC sp_help [VinFast Stock Price History];

Select Vol, Change
from dbo.[VinFast Stock Price History];

ALTER TABLE dbo.[VinFast Stock Price History]
ADD Vol_num DECIMAL(18, 2),
    Change_num DECIMAL(5, 4);

Update dbo.[VinFast Stock Price History]
set Vol_num = 
    Case 
        When Vol like '%K' then TRY_CAST(replace(Vol, 'K', '') as decimal(18, 2))*1000
        When Vol like '%M' then TRY_CAST(replace(Vol, 'M', '') as decimal(18, 2))*1000000
        else TRY_CAST (Vol as Decimal(18, 2))
    End;

    Alter table dbo.[VinFast Stock Price History]
    alter column Change_num DECIMAL(10, 4);

    Update dbo.[VinFast Stock Price History]
    set Change_num = try_cast(replace(Change, '%', '') as DECIMAL(10,4))/100
    WHERE Change like '%[0-9]%[%]';

    SELECT Date, Vol, Change
    INTO Vol_Change_Backup
    FROM dbo.[VinFast Stock Price History];


    alter table dbo.[VinFast Stock Price History]
    drop column Vol, Change;

    EXEC sp_rename 'dbo.[VinFast Stock Price History].Vol_num', 'Vol', 'COLUMN';
    EXEC sp_rename 'dbo.[VinFast Stock Price History].Change_num', 'Change', 'COLUMN';


    EXEC sp_help [VinFast Stock Price History Raw];

USE [Vinfast Historical Stock Data];
GO

-- 2. Volatility (High - Low)
Alter table dbo.[VinFast Stock Price History]
alter column High decimal (10,4); 

Alter table dbo.[VinFast Stock Price History]
alter column Low decimal (10,4); 

Alter table dbo.[VinFast Stock Price History]
add Volatility decimal (10,4); 

Update dbo.[VinFast Stock Price History]
    set Volatility = 
        case 
            when High is not null and Low is not null
            then High - Low
            else Null
        end;

-- 2. Calculate 7-day rolling volatility
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

EXEC sp_rename 'dbo.[VinFast Stock Price History].Daily Return', 'Daily_Return', 'COLUMN';

-- 3. Daily % Change (Close vs Open)
-- This is where I want to know which day is bullish or bearish
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

-- 4. Peak Drawdown
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

-- 5. Next day return
-- This helps retail investors know what happened after a spike/drop (if there was a spike/drop)
-- and if we know how the stock behaved after such events, we can predict when to buy and when to sell that can earn a big profit for us.

alter table dbo.[VinFast Stock Price History]
add Next_Day_Return Decimal (10,4);

Update V
    set Next_Day_Return = try_cast((Next.[Close]-V.[Close])*1.0/V.[Close] as Decimal (10, 4)) 
    from dbo.[VinFast Stock Price History] as V
    join dbo.[VinFast Stock Price History] as Next
        on Next.[Date] = DATEADD(Day, 1, V.[Date]); -- This worked but not correct since stock is not traded on weekends/holidays. and DATEADD syntax only add calendar days.

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
    -- Because 2025-06-27 is the last row in your table => NULL for Next_Day_Return for this row — and LEAD() can’t find “tomorrow” (2025-06-28) because there’s no data for the next day.

    USE [Vinfast Historical Stock Data];
    Go

    With Drops as (
    Select FLOOR (Change_OpenClose) as Drop_Threshold,
    Next_Day_Return
    from dbo.[VinFast Stock Price History]
    where Change_OpenClose < 0
    )

    Select Drop_Threshold,
     COUNT(*) AS Total_Cases,
    Sum(Case when Next_Day_Return >= 0.02 then 1 else 0 end) as rebound_frequency,
    Round( 100.0 * (Case when Next_Day_Return >= 0.02 then 1 else 0 end/count(*)),2) as Win_rate
    from Drops
    Group by Drop_Threshold
    Order by Drop_Threshold;




    Select FLOOR (Change_OpenClose) as Drop_Threshold, -- Rounds a number down to the nearest whole integer
    count(*) as Total_Cases,
    Sum(Case when Next_Day_Return >= 0.02 then 1 else 0 end) as rebound_frequency,
    Round( 100.0 * (Case when Next_Day_Return >= 0.02 then 1 else 0 end/count(*)),2) as Win_rate -- Although you already alias a name for each, but SQL process in this order: 1 FROM / WHERE, 2 GROUP BY, 3 SELECT expressions evaluated, 4 Aliases assigned, 5 ORDER BY, etc. So if you use alias to calculate, then it would be too early since SQL don't know if it exists yet.
    from dbo.[VinFast Stock Price History] 
    where Change_OpenClose < 0
    Group by FLOOR (Change_OpenClose)
    Order by Drop_Threshold;

    SELECT 
    FLOOR(Change_OpenClose) AS Drop_Threshold,
    Next_Day_Return
FROM dbo.[VinFast Stock Price History]
WHERE Change_OpenClose < 0;

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


SELECT MIN(Change_OpenClose) as Min, MAX(Change_OpenClose) as Max
FROM dbo.[VinFast Stock Price History]
WHERE Change_OpenClose < 0;

USE [Vinfast Historical Stock Data];
    Go

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

SELECT
    Drop_Threshold_Percent,
    SUM(CASE WHEN Buy_Signal = 1 THEN 1 ELSE 0 END) AS Total_Buying_Opportunities, 
    SUM(CASE WHEN Buy_Signal = 1 AND Rebound_Next_day = 1 THEN 1 ELSE 0 END) AS Total_Rebounds,
    ROUND(100.0 * SUM(CASE WHEN Buy_Signal = 1 AND Rebound_Next_day = 1 THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN Buy_Signal = 1 THEN 1 ELSE 0 END), 0),2) AS Success_Rate
    -- Win_Rate_Percent = 'Of all the days when the stock dropped enough to trigger a buy, how many times did the price actually go up by at least 2% the next day?'
FROM dbo.BuyDipStrategy
GROUP BY Drop_Threshold_Percent
ORDER BY Drop_Threshold_Percent;

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

select *
from dbo.MonthlyKPI;

USE [Vinfast Historical Stock Data];
    Go

select * 
from dbo.BuyDipStrategy;

ALTER TABLE dbo.BuyDipStrategy
ADD Win_Label AS (
    CASE 
        WHEN Win_or_not = 1 THEN 'Yes'
        WHEN Win_or_not = 0 THEN 'No'
        ELSE NULL
    END
);

select * 
from dbo.Stock_Behavior_Weekday;
ALTER TABLE Stock_Behavior_Weekday
ADD Weekday_Name_Abbrev AS FORMAT([Date], 'ddd');  -- This adds it as a computed column
