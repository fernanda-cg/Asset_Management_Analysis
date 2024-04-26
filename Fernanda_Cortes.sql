USE invest;

# Going over client's portfolio 
CREATE VIEW fcg_clientF AS
SELECT c.customer_id, c.full_name,
	   a.account_id, a.opt38_desc AS "acc_type", 
	   h.ticker, h.date, h.value AS "price", h.price_type, h.quantity, 
       s.security_name, s.sec_type, s.major_asset_class, s.minor_asset_class
FROM customer_details c
INNER JOIN account_dim a
ON c.customer_id = a.client_id
LEFT JOIN holdings_current h 
ON a.account_id = h.account_id
LEFT JOIN security_masterlist s
ON h.ticker = s.ticker
WHERE c.customer_id = 148
ORDER BY h.quantity DESC
;

# Creating client's view
CREATE VIEW Fernanda_Cortes AS
SELECT ticker, date, value AS "price", price_type
FROM pricing_daily
WHERE ticker IN (SELECT DISTINCT ticker FROM fcg_clientF)
ORDER BY ticker, date DESC, price_type;

# Getting ROR for the last 12, 18 and 24 months
CREATE VIEW fcg_ROR AS 
SELECT z.*, 
	   (z.price - z.P0_12)/z.P0_12 AS ROR_12, 
       (z.price - z.P0_18)/z.P0_18 AS ROR_18, 
       (z.price - z.P0_24)/z.P0_24 AS ROR_24
FROM (SELECT *, 
	  LAG(price, 250)OVER(PARTITION BY ticker ORDER BY date) AS P0_12,
	  LAG(price, 375)OVER(PARTITION BY ticker ORDER BY date) AS P0_18,
      LAG(price, 500)OVER(PARTITION BY ticker ORDER BY date) AS P0_24
FROM Fernanda_Cortes
WHERE price_type = "Adjusted"
		AND date > "2021-09-15") AS z
WHERE date = "2023-10-06"
ORDER BY ticker;

# Getting portfolio return (weighted average)
SELECT sum(ROR_12 * (price * quantity))/sum(price * quantity) AS portfolio_ROR_12, 
	   sum(ROR_18 * (price * quantity))/sum(price * quantity) AS portfolio_ROR_18,
       sum(ROR_24 * (price * quantity))/sum(price * quantity) AS portfolio_ROR_24
FROM fcg_ROR
INNER JOIN (SELECT ticker, sum(quantity) as "quantity"
FROM fcg_clientF
GROUP BY ticker) as F
ON F.ticker = fcg_ROR.ticker;

# Calculating daily mu - mean, sigma - stand dev and sharpe ratio - risk adjusted return
SELECT y.ticker, avg(y.ROR) AS mu_ROR , std(y.ROR) AS sigma, avg(y.ROR)/std(y.ROR) AS shrp 
FROM(SELECT z.*, (z.price-z.P0)/z.P0 AS ROR
FROM (SELECT *, 
	  LAG(price, 1)OVER(PARTITION BY ticker ORDER BY date) AS P0
FROM Fernanda_Cortes
WHERE price_type = "Adjusted"
		AND date > "2022-10-10") AS z
) y
GROUP BY ticker
ORDER BY avg(y.ROR)/std(y.ROR) DESC;

# Calculating risk adjusted return from tickers not in my client's porfolio
SELECT y.ticker, avg(y.ROR) AS mu_ROR , std(y.ROR) AS sigma, avg(y.ROR)/std(y.ROR) AS shrp 
FROM(SELECT z.*, (z.value-z.P0)/z.P0 AS ROR
FROM (SELECT *, 
	  LAG(value, 1)OVER(PARTITION BY ticker ORDER BY date) AS P0
FROM pricing_daily
WHERE price_type = "Adjusted"
		AND date > "2022-10-10"
        AND ticker NOT IN (SELECT DISTINCT ticker FROM fcg_clientF)) AS z
) y
GROUP BY ticker
ORDER BY avg(y.ROR)/std(y.ROR) DESC;

# Calculating portfolio daily mu, sigma and sharpe
SELECT avg(y.p_ROR) AS p_mu_ROR , std(y.p_ROR) AS sigma, avg(y.p_ROR)/std(y.p_ROR) AS shrp 
FROM (SELECT z.*, (z.p_price-z.p_P0)/z.p_P0 AS p_ROR
FROM (SELECT date, sum(price * (P_AUM/total_P_AUM)) as p_price,
			 sum(P0 * (P0_AUM/total_P0_AUM)) as p_P0
FROM (SELECT Fernanda_Cortes.ticker, Fernanda_Cortes.date, price, price_type, quantity, 
	  LAG(price, 1)OVER(PARTITION BY Fernanda_Cortes.ticker ORDER BY date) AS P0,
      price*quantity AS P_AUM,
      total_P_AUM,
      (LAG(price, 1)OVER(PARTITION BY Fernanda_Cortes.ticker ORDER BY date))*quantity AS P0_AUM, 
      total_P0_AUM
FROM Fernanda_Cortes
LEFT JOIN (SELECT ticker, sum(quantity) as "quantity"
FROM fcg_clientF
GROUP BY ticker) as F
ON Fernanda_Cortes.ticker = F.ticker
LEFT JOIN (SELECT date, total_P_AUM,
		LAG(total_P_AUM, 1)OVER(ORDER BY date) AS total_P0_AUM
FROM (SELECT date, sum(price*quantity) as total_P_AUM
FROM Fernanda_Cortes
LEFT JOIN (SELECT ticker, sum(quantity) as "quantity"
FROM fcg_clientF
GROUP BY ticker) as F
ON Fernanda_Cortes.ticker = F.ticker
WHERE price_type = "Adjusted"
		AND date > "2022-10-10"
GROUP BY date) AS A) AS B
ON Fernanda_Cortes.date = B.date
WHERE price_type = "Adjusted"
		AND Fernanda_Cortes.date > "2022-10-10") AS C
GROUP BY date) AS z) AS y;









