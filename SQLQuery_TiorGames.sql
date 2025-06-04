/**
* Sample Test Query
**/
SELECT * FROM PlayerDim;

-------------
---Question 1
/**
* Query 1: Top Revenue Generating Games This Year
*
* Business Rationale: Identifies peak online sales dates to guide future marketing and logistics planning.Helps in determining optimal promotional periods and ensuring adequate server infrastructure and stock during those times.
* Explanation:
* Uses RANK() as an OLAP function to rank dates by total online revenue.
* OnlineSalesFact is the fact table, and it aggregates MerchandiseSoldPND by DateID.
* Purpose: Helps marketing and sales teams identify the most successful online sales dates, useful for planning future campaigns or peak-time logistics.
**/
SELECT 
    DateID, 
    SUM(MerchandiseSoldPND) AS TotalOnlineRevenuePND,
    RANK() OVER (ORDER BY SUM(MerchandiseSoldPND) DESC) AS RevenueRank
FROM 
    OnlineSalesFact
GROUP BY 
    DateID;

/**
* Query [Other]: Highest Revenue Events by Type (DENSE_RANK)
*
* Business Rationale: Enables event managers to evaluate which events generated the most revenue.This insight supports future event planning and helps prioritize investment in high-performing event formats.
* Explanation:
* Combines multiple revenue metrics (TicketsSoldPND, MerchandiseSoldPND, PromotionRevenue) to compute total revenue per event.
* Uses DENSE_RANK() to avoid gaps in rankings when revenues tie.
* Purpose: Assists event managers in understanding which events are the most financially successful, guiding planning and investment decision
**/    
SELECT 
    EventID,
    SUM(TicketsSoldPND + MerchandiseSoldPND + PromotionRevenue) AS TotalEventRevenuePND,
    DENSE_RANK() OVER (ORDER BY SUM(TicketsSoldPND + MerchandiseSoldPND + PromotionRevenue) DESC) AS RevenuePosition
FROM 
    EventFact
GROUP BY 
    EventID;

/**
* Query 2: Longest Average Game Duration by Game Stage (AVG + GROUP BY)
*
* Business Rationale: Helps developers optimize pacing by understanding how game stages affect duration.This aids in designing engaging and balanced gameplay that aligns with user expectations and attention spans.
* Explanation:
* Aggregates GameDuration by GameStage, showing how long each stage tends to last.
* Joins the GameFact and GameDim tables.
* Purpose: Supports game designers in pacing and player experience optimization by revealing which stages are too long or too short
**/     
SELECT 
    gd.GameStage, 
    AVG(gf.GameDuration) AS AvgGameDurationMinutes
FROM 
    GameFact gf
JOIN 
    GameDim gd ON gf.GameID = gd.GameID
GROUP BY 
    gd.GameStage
ORDER BY 
    AvgGameDurationMinutes DESC;

/**
* Query [Other]: Spectator Segments Ranked by VIP Attendance (RANK + Fact Dimension Join)
*
* Business Rationale: Aids VIP engagement strategy by highlighting which events attract top-tier guests.
* Explanation:
* Uses RANK() to sort events based on the number of VIP spectators.
* Analyzes VIP attendance trends using data from the EventFact table.
* Purpose: Helps event planners tailor offerings to high-value attendees and better understand which events attract VIPs. Valuable for refining invitation strategies, sponsorship negotiations, and premium experience offerings.
**/     
SELECT 
    ef.EventID,
    ef.VIPSpectatorsNumber,
    RANK() OVER (ORDER BY ef.VIPSpectatorsNumber DESC) AS VIPAttendanceRank
FROM 
    EventFact ef;

/**
* Query 3: Top Dates by Refund Volume (SUM + RANK)
*
* Business Pinpoints dates with high refund volume to investigate causes and mitigate future loss. Helps identify operational, customer service, or quality issues linked to specific campaigns or events.
* Explanation:
* Sums up different refund types to determine total refund volume per date.
* Uses RANK() to identify and rank problematic dates.
* Purpose: Assists the finance and quality assurance teams in investigating spikes in refunds and preventing future issues
**/      
SELECT 
    DateID, 
    SUM(TicketsRefundedPND + MerchandiseRefundedPND) AS TotalRefundsPND,
    RANK() OVER (ORDER BY SUM(TicketsRefundedPND + MerchandiseRefundedPND) DESC) AS RefundRank
FROM 
    RefundFact
GROUP BY 
    DateID;

/**
* Query [Other]: Most Frequent Pause Reasons in Games (COUNT + DENSE_RANK)
*
* Business Guides improvements in technical performance or player experience by analyzing pause causes.Useful for the QA and dev teams to focus on the most disruptive issues to gameplay flow.
* Explanation:
* Counts how many times each pause reason appears.
* Uses DENSE_RANK() to classify the most frequent causes.
* Purpose: Supports technical and product teams by identifying leading causes for game pauses, which can guide system performance improvements and player satisfaction efforts.
**/      
SELECT 
    pd.PauseReason, 
    COUNT(*) AS OccurrenceCount,
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS PauseReasonRank
FROM 
    GameFact gf
JOIN 
    PauseDim pd ON gf.PauseID = pd.PauseID
GROUP BY 
    pd.PauseReason;


/**
* Query 4: Year-over-Year (YoY) Growth in Online Merchandise Sales by Country
*
Measure country-wise year-over-year (YoY) growth in online merchandise sales.
Business Rationale:

Supports market expansion and performance monitoring across regions.
DW Concepts:

OLAP: LAG(), PARTITION BY.

Time Dimension: DateDim.
**/     
SELECT 
    ld.Country,
    dd.DateYear AS CalendarYear,
    SUM(sf.MerchandiseSoldPND) AS TotalSalesPND,
    LAG(SUM(sf.MerchandiseSoldPND)) OVER (PARTITION BY ld.Country ORDER BY dd.DateYear) AS PrevYearSalesPND,
    ROUND(
        CASE 
            WHEN LAG(SUM(sf.MerchandiseSoldPND)) OVER (PARTITION BY ld.Country ORDER BY dd.DateYear) IS NULL THEN NULL
            ELSE 
                (SUM(sf.MerchandiseSoldPND) - LAG(SUM(sf.MerchandiseSoldPND)) OVER (PARTITION BY ld.Country ORDER BY dd.DateYear)) 
                * 100.0 / LAG(SUM(sf.MerchandiseSoldPND)) OVER (PARTITION BY ld.Country ORDER BY dd.DateYear)
        END, 2
    ) AS YoYGrowthPercent
FROM 
    OnlineSalesFact sf
JOIN 
    DateDim dd ON sf.DateID = dd.DateID
JOIN 
    MerchandiseDim md ON sf.MerchandiseID = md.MerchandiseID
JOIN 
    ProviderDim pd ON md.MerchandiseProviderID = pd.ProviderID
JOIN 
    LocationDim ld ON pd.ProviderLocation = ld.LocationID
GROUP BY 
    ld.Country, dd.DateYear;


/**
* Query 8: Top 3 Games by Lifetime Engagement Per Game Stage Using NTILE
*
Query 2 - 
Purpose:

Identify top-performing games within each game stage.
Business Rationale:

Optimizes investment in high-engagement titles.
DW Concepts:

OLAP: NTILE() ranking.

Game Stage Dimension: GameDim.
**/ 

SELECT * FROM (
    SELECT 
        gd.GameStage,
        gd.GameID,
        COUNT(*) AS Sessions,
        AVG(gf.GameDuration) AS AvgDuration,
        NTILE(3) OVER (PARTITION BY gd.GameStage ORDER BY COUNT(*) DESC) AS PerformanceTier
    FROM 
        GameFact gf
    JOIN 
        GameDim gd ON gf.GameID = gd.GameID
    GROUP BY 
        gd.GameStage, gd.GameID
) t
WHERE PerformanceTier = 1;

/**
* Query 9: Event Ticket Refund Ratio by Event Type (based on TicketEvent)
*
Purpose:

Identify top-performing games within each game stage.
Business Rationale:

Optimizes investment in high-engagement titles.
DW Concepts:

OLAP: NTILE() ranking.

Game Stage Dimension: GameDim.
**/ 
WITH MonthlySales AS (
    SELECT 
        ld.Country,
        FORMAT(dd.DateValue, 'yyyy-MM') AS SalesMonth,
        SUM(sf.MerchandiseSoldPND) AS MonthlySales,
        RANK() OVER (PARTITION BY ld.Country ORDER BY SUM(sf.MerchandiseSoldPND) DESC) AS CountryRank
    FROM 
        OnlineSalesFact sf
    JOIN 
        DateDim dd ON sf.DateID = dd.DateID
    JOIN 
        MerchandiseDim md ON sf.MerchandiseID = md.MerchandiseID
    JOIN 
        ProviderDim pd ON md.MerchandiseProviderID = pd.ProviderID
    JOIN 
        LocationDim ld ON pd.ProviderLocation = ld.LocationID
    GROUP BY 
        ld.Country, FORMAT(dd.DateValue, 'yyyy-MM')
),
TopCountries AS (
    SELECT DISTINCT Country FROM MonthlySales WHERE CountryRank <= 5
)
SELECT 
    ms.Country, 
    ms.SalesMonth,
    SUM(ms.MonthlySales) OVER (PARTITION BY ms.Country ORDER BY ms.SalesMonth ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumulativeSales
FROM 
    MonthlySales ms
JOIN 
    TopCountries tc ON ms.Country = tc.Country;


/** Query 10: VIP Attendance Share by Event Region
*
Purpose:
Calculate VIP engagement as a percentage by region.
Business Rationale:

Enhance elite gamer/event targeting strategies.
DW Concepts:

OLAP ratio calculation.

Regional grouping via LocationDim.
**/ 
WITH EventRegion AS (
    SELECT 
        ef.EventID, ef.VIPSpectatorsNumber, ld.Country AS Region
    FROM EventFact ef
    JOIN EventDim ed ON ef.EventID = ed.EventID
    JOIN StadiumDim sd ON ed.EventStartDateID = sd.StadiumID
    JOIN LocationDim ld ON sd.StadiumLocationID = ld.LocationID
),
TotalVIP AS (
    SELECT Region, SUM(VIPSpectatorsNumber) AS TotalVIPs
    FROM EventRegion
    GROUP BY Region
)
SELECT 
    er.EventID,
    er.Region,
    er.VIPSpectatorsNumber,
    ROUND(CAST(er.VIPSpectatorsNumber AS FLOAT) / tv.TotalVIPs * 100, 2) AS VIPSharePercent
FROM 
    EventRegion er
JOIN 
    TotalVIP tv ON er.Region = tv.Region;




-------------
---Question 3

-- To compute unexpected sales difference
WITH UnexpectedSales AS (
    SELECT 
        osf.MerchandiseID,
        md.MerchandiseType,
        dd.DateYear,
        ld.Country,
        ABS(osf.MerchandiseSold - osf.MerchandiseStocked) AS UnexpectedDifference
    FROM 
        OnlineSalesFact osf
    JOIN DateDim dd ON osf.DateID = dd.DateID
    JOIN MerchandiseDim md ON osf.MerchandiseID = md.MerchandiseID
    JOIN ProviderDim pd ON md.MerchandiseProviderID = pd.ProviderID
    JOIN LocationDim ld ON pd.ProviderLocation = ld.LocationID
)

-- Part A: Most unexpected sales in Japan
SELECT TOP 1 
    'Part A' AS Part,
    MerchandiseType,
    DateYear,
    UnexpectedDifference
FROM UnexpectedSales
WHERE Country = 'Japan'
ORDER BY UnexpectedDifference DESC;

WITH UnexpectedSales AS (
    SELECT 
        osf.MerchandiseID,
        md.MerchandiseType,
        dd.DateYear,
        ld.Country,
        ABS(osf.MerchandiseSold - osf.MerchandiseStocked) AS UnexpectedDifference
    FROM 
        OnlineSalesFact osf
    JOIN DateDim dd ON osf.DateID = dd.DateID
    JOIN MerchandiseDim md ON osf.MerchandiseID = md.MerchandiseID
    JOIN ProviderDim pd ON md.MerchandiseProviderID = pd.ProviderID
    JOIN LocationDim ld ON pd.ProviderLocation = ld.LocationID
)

-- Part B: Least unexpected sales across all countries and years
SELECT TOP 1 
    'Part B' AS Part,
    MerchandiseType,
    Country,
    DateYear,
    UnexpectedDifference
FROM UnexpectedSales
ORDER BY UnexpectedDifference ASC;


----------------------------------------------------------------

SELECT 
    d.full_date,
    se.event_name,
    ch.champion_name,
    p.promotion_name,
    f.views,
    f.watch_time,
    f.revenue
FROM StreamingMetricsFact f
JOIN DateDim d ON f.date_key = d.date_key
JOIN StreamingEventDim se ON f.event_key = se.event_key
JOIN ChampionDim ch ON f.champion_key = ch.champion_key
JOIN PromotionDim p ON f.promotion_key = p.promotion_key
WHERE d.full_date BETWEEN '2025-01-01' AND '2025-06-01';