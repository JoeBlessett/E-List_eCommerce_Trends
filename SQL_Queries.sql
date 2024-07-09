/*

==========================
SQL Project - Elist Analysis
==========================

*/

-- What were the order counts, sales, and Average Order Value (AOV) for Macbooks sold in North America for each quarter across all years?
    -- Tables: Order, Customers, Geo_Lookup
    -- Columns: Quarter Per Year, COUNT(order_id), SUM(usd_price) & AVG(usd_price)
    -- Filter: Where product_name LIKE 'Mackbook%' AND region = 'NA'

    -- FINDINGS: - Average of 98 units sold per quarter
                 - Average of $155K sales per quarter

SELECT DATE_TRUNC(purchase_ts, quarter) as Purchase_Quarter,
  COUNT(orders.id) as Order_Count,
  ROUND(SUM (orders.usd_price), 2) as Sales,
  ROUND(AVG(orders.usd_price), 2) as AOV
FROM core.orders
LEFT JOIN core.customers
  ON customers.id = orders.customer_id
LEFT JOIN core.geo_lookup
  ON customers.country_code = geo_lookup.country
Where region = 'NA'
and product_name LIKE 'Macbook%'
GROUP BY 1
ORDER BY 1 desc;

-- For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver?
    -- Tables: Order, Order_Status, Customers, Geo_Lookup
    -- Columns: Return the region with the highest AVG(delivery_ts - purchase_ts)
    -- Filter: Where 1) orders in 2022 on the website OR 2) orders placed on mobile app (all years)

    -- FINDINGS: - EMEA has highest delivery time, but all regions are similar (~7.5 days) 

SELECT geo_lookup.region,
  ROUND(AVG(date_diff(order_status.delivery_ts, order_status.purchase_ts, day)), 2) as Time_to_Deliver
FROM core.orders
LEFT JOIN core.customers
  ON customers.id = orders.customer_id
LEFT JOIN core.order_status
  ON order_status.order_id = orders.id
LEFT JOIN core.geo_lookup
  ON customers.country_code = geo_lookup.country
WHERE (EXTRACT( year from orders.purchase_ts) = 2022 AND orders.purchase_platform = 'website')
OR orders.purchase_platform = 'mobile app'
GROUP BY 1
ORDER BY 2 desc;

-- What was the refund rate and refund count for each product overall?
    -- Tables: Order JOINED with Order_status
    -- Columns: CASE WHEN product_name to Product_Clean, SUM(order_status.refund_ts) & AVG(order_status.refund_ts)
    -- Ordered: By highest rate to lowest

    -- FINDINGS: - Top refunded product - Thinkpad Laptop(11.7% refund rate)
                 - Macbook and iPhone also have very high refund rates(11.4% & 7.6%, respectively)
                 - Apple Airpods have the highest number of refund(2.6K)

SELECT CASE WHEN orders.product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else orders.product_name end as Product_Clean,
  SUM(CASE WHEN order_status.refund_ts is not null then 1 else 0 end) as Refunds,
  AVG(CASE WHEN order_status.refund_ts is not null then 1 else 0 end) as Refund_Rate
FROM core.orders
LEFT JOIN core.order_status
  ON orders.id = order_status.order_id
GROUP BY 1
ORDER BY 3 desc;

-- Within each region, what is the most popular product?
    -- Join all tables to return region and count of orders (most popular product = product with most orders) 
    -- Ordered: Products by count in each region and return the top selling product for each

    -- FINDINGS: - Apple Airpods are the top product by order count across all regions
                 - North America has the highest number of Airpod purchases consistently across all regions. 
                 
WITH Sales_By_Product as (
SELECT region,
  product_name,
  COUNT(DISTINCT orders.id) as Total_Orders
FROM core.orders
LEFT JOIN core.customers
  ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup
  ON geo_lookup.country = customers.country_code
GROUP BY 1, 2)

SELECT*,
  row_number() over (partition by region order by Total_Orders desc) as Order_Ranking
From Sales_By_Product
QUALIFY row_number() over (partition by region order by Total_Orders desc) = 1;

-- How does the time to make a purchase differ between loyalty customers vs. non-loyalty customers?
    -- Tables: Join Order and Customers
    -- Columns: ROUNDED AVG of a DATE_DIFF of order_status.purchase_ts & customers.created_on by day annd month
   
    -- FINDINGS: - On average, loyalty customers are typically making purchases 30% sooner vs non-loyalty customers after creating their accounts.

SELECT customers.loyalty_program,
  ROUND(AVG(DATE_DIFF(order_status.purchase_ts, customers.created_on, day)),1) as Days_to_Purchase,
  ROUND(AVG(DATE_DIFF(order_status.purchase_ts, customers.created_on, month)),1) as Months_to_Purchase
FROM core.customers
LEFT JOIN core.orders
  ON orders.customer_id = customers.id
LEFT JOIN core.order_status
  ON order_status.order_id = orders.id
GROUP BY 1;
