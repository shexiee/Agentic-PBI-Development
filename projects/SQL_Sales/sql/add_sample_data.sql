/*
    Adds generated sample data to LocalDemoDb so the SQL_Sales report has something to show.

    - 38 customers (40 in total) and 12 products (15 in total)
    - 420 orders from 2025-10-01 to 2026-09-30, each with 1-4 order lines
    - Order volume grows through the year, with a rush from 20 November to Christmas
    - Cheaper products sell more often, and a handful of customers order far more than the rest

    The script only inserts rows; existing rows are left as they are. Values come from hashes of
    row numbers rather than NEWID()/RAND(), so a run against the original database always
    produces the same data. Running it a second time does nothing.

    Run:
        sqlcmd -S "(localdb)\MSSQLLocalDB" -d LocalDemoDb -E -C -b -i add_sample_data.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM dbo.Sales WHERE SaleDate < '20261001')
BEGIN
    PRINT 'Sample orders are already in LocalDemoDb. Nothing to do.';
    RETURN;
END;

BEGIN TRANSACTION;

/* Customers ----------------------------------------------------------------------------------- */

DECLARE @MaxCustomerId int = (SELECT ISNULL(MAX(CustomerId), 0) FROM dbo.Customers);

INSERT INTO dbo.Customers (CustomerId, CustomerName, City)
SELECT @MaxCustomerId + ROW_NUMBER() OVER (ORDER BY v.Seq), v.CustomerName, v.City
FROM (VALUES
    ( 1, N'Maya Patel',      N'San Francisco'),
    ( 2, N'Liam Murphy',     N'Boston'),
    ( 3, N'Sofia Garcia',    N'Los Angeles'),
    ( 4, N'Noah Kim',        N'Seattle'),
    ( 5, N'Priya Sharma',    N'Seattle'),
    ( 6, N'Olivia Brown',    N'Chicago'),
    ( 7, N'Mateo Rodriguez', N'Phoenix'),
    ( 8, N'Hannah Schmidt',  N'Denver'),
    ( 9, N'Daniel Okafor',   N'Austin'),
    (10, N'Emma Wilson',     N'Portland'),
    (11, N'Lucas Silva',     N'San Diego'),
    (12, N'Aisha Rahman',    N'New York'),
    (13, N'James Carter',    N'Chicago'),
    (14, N'Mei Tanaka',      N'Seattle'),
    (15, N'Carlos Mendoza',  N'Los Angeles'),
    (16, N'Grace Johnson',   N'Denver'),
    (17, N'Omar Haddad',     N'New York'),
    (18, N'Chloe Martin',    N'San Francisco'),
    (19, N'Ryan Walker',     N'Austin'),
    (20, N'Isabel Torres',   N'Phoenix'),
    (21, N'Kevin Park',      N'Los Angeles'),
    (22, N'Fatima Ali',      N'Chicago'),
    (23, N'Benjamin Clark',  N'Boston'),
    (24, N'Leah Cohen',      N'New York'),
    (25, N'Diego Ramirez',   N'San Diego'),
    (26, N'Nina Petrova',    N'Seattle'),
    (27, N'Samuel Adeyemi',  N'Portland'),
    (28, N'Zoe Thompson',    N'Denver'),
    (29, N'Arjun Mehta',     N'San Francisco'),
    (30, N'Elena Rossi',     N'Boston'),
    (31, N'Marcus Hill',     N'Phoenix'),
    (32, N'Yuki Sato',       N'Portland'),
    (33, N'Rosa Delgado',    N'Austin'),
    (34, N'Thomas Becker',   N'Chicago'),
    (35, N'Ana Costa',       N'San Diego'),
    (36, N'Jamal Wright',    N'New York'),
    (37, N'Lily Chen',       N'Los Angeles'),
    (38, N'Ethan Nguyen',    N'San Francisco')
) AS v (Seq, CustomerName, City)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Customers AS c WHERE c.CustomerName = v.CustomerName);

/* Products ------------------------------------------------------------------------------------ */

DECLARE @MaxProductId int = (SELECT ISNULL(MAX(ProductId), 0) FROM dbo.Products);

INSERT INTO dbo.Products (ProductId, ProductName, UnitPrice)
SELECT @MaxProductId + ROW_NUMBER() OVER (ORDER BY v.Seq), v.ProductName, v.UnitPrice
FROM (VALUES
    ( 1, N'USB-C Hub',         39.99),
    ( 2, N'Webcam',            69.99),
    ( 3, N'Headset',           89.99),
    ( 4, N'Laptop Stand',      34.99),
    ( 5, N'Docking Station',  159.99),
    ( 6, N'External SSD 1TB', 119.99),
    ( 7, N'Mouse Pad',         12.99),
    ( 8, N'HDMI Cable',        14.99),
    ( 9, N'Wireless Charger',  29.99),
    (10, N'Desk Lamp',         44.99),
    (11, N'Office Chair',     249.99),
    (12, N'Standing Desk',    399.99)
) AS v (Seq, ProductName, UnitPrice)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Products AS p WHERE p.ProductName = v.ProductName);

/* Sales --------------------------------------------------------------------------------------- */

-- Each random value is the first 4 bytes of an MD5 hash of "<row>|<purpose>", scaled to [0, 1).

DECLARE @MaxSaleId int = (SELECT ISNULL(MAX(SaleId), 0) FROM dbo.Sales);
DECLARE @CustomerCount int = (SELECT COUNT(*) FROM dbo.Customers);

SELECT CustomerId, ROW_NUMBER() OVER (ORDER BY CustomerId) AS CustomerRank
INTO #CustomerRank
FROM dbo.Customers;

-- 360 orders spread over the year, denser towards the end (day = 365 * u^0.75),
-- plus 60 between 20 November and 24 December. Customers are picked with
-- rank = N * u^1.6, which favours the lower ranks.
WITH Numbers AS (
    SELECT TOP (420) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
),
Orders AS (
    SELECT
        Numbers.n,
        CASE
            WHEN Numbers.n <= 360
                THEN DATEADD(day, CAST(365 * POWER(r.uDay, 0.75) AS int), CAST('20251001' AS date))
            ELSE DATEADD(day, CAST(35 * r.uDay AS int), CAST('20251120' AS date))
        END AS SaleDate,
        CAST(@CustomerCount * POWER(r.uCustomer, 1.6) AS int) + 1 AS CustomerRank
    FROM Numbers
    CROSS APPLY (SELECT
        CONVERT(bigint, CONVERT(binary(4), HASHBYTES('MD5', CONCAT(Numbers.n, '|day')))) / 4294967296e0 AS uDay,
        CONVERT(bigint, CONVERT(binary(4), HASHBYTES('MD5', CONCAT(Numbers.n, '|customer')))) / 4294967296e0 AS uCustomer
    ) AS r
)
SELECT
    @MaxSaleId + ROW_NUMBER() OVER (ORDER BY o.SaleDate, o.n) AS SaleId,
    cr.CustomerId,
    o.SaleDate
INTO #NewSales
FROM Orders AS o
JOIN #CustomerRank AS cr ON cr.CustomerRank = o.CustomerRank;

INSERT INTO dbo.Sales (SaleId, CustomerId, SaleDate)
SELECT SaleId, CustomerId, SaleDate
FROM #NewSales;

/* Sale items ---------------------------------------------------------------------------------- */

DECLARE @MaxSaleItemId int = (SELECT ISNULL(MAX(SaleItemId), 0) FROM dbo.SaleItems);

-- Each order takes 1-4 different products. Products are drawn by weighted sampling without
-- replacement: every product scores u^(1/weight) and the order keeps the top scores. With
-- weight = 1 / SQRT(price), the score is u^SQRT(price), so cheaper products come up more often.
WITH Picks AS (
    SELECT
        s.SaleId,
        p.ProductId,
        p.UnitPrice,
        lc.LineCount,
        rp.uQty,
        ROW_NUMBER() OVER (
            PARTITION BY s.SaleId
            ORDER BY POWER(rp.uPick, SQRT(p.UnitPrice)) DESC, p.ProductId
        ) AS PickRank
    FROM #NewSales AS s
    CROSS APPLY (SELECT
        CONVERT(bigint, CONVERT(binary(4), HASHBYTES('MD5', CONCAT(s.SaleId, '|lines')))) / 4294967296e0 AS uLines
    ) AS rl
    CROSS APPLY (SELECT
        CASE WHEN rl.uLines < 0.45 THEN 1 WHEN rl.uLines < 0.75 THEN 2 WHEN rl.uLines < 0.92 THEN 3 ELSE 4 END AS LineCount
    ) AS lc
    CROSS JOIN dbo.Products AS p
    CROSS APPLY (SELECT
        CONVERT(bigint, CONVERT(binary(4), HASHBYTES('MD5', CONCAT(s.SaleId, '|', p.ProductId, '|pick')))) / 4294967296e0 AS uPick,
        CONVERT(bigint, CONVERT(binary(4), HASHBYTES('MD5', CONCAT(s.SaleId, '|', p.ProductId, '|qty')))) / 4294967296e0 AS uQty
    ) AS rp
)
INSERT INTO dbo.SaleItems (SaleItemId, SaleId, ProductId, Quantity, UnitPrice)
SELECT
    @MaxSaleItemId + ROW_NUMBER() OVER (ORDER BY SaleId, PickRank),
    SaleId,
    ProductId,
    CASE
        WHEN UnitPrice < 50 THEN CASE WHEN uQty < 0.60 THEN 1 WHEN uQty < 0.85 THEN 2 ELSE 3 END
        ELSE CASE WHEN uQty < 0.92 THEN 1 ELSE 2 END
    END,
    UnitPrice
FROM Picks
WHERE PickRank <= LineCount;

COMMIT TRANSACTION;

PRINT 'Sample data added to LocalDemoDb.';
