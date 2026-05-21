-- QUESTION 1: How many customers did we lose and where?
WITH churn_total AS (
    SELECT 
        COUNT(*) AS total_customers,
        SUM(exited) AS total_churned,
        ROUND((SUM(exited)::NUMERIC / COUNT(*)) * 100, 2) AS churn_rate_total
    FROM accounts
)
SELECT 
    c.geography,
    COUNT(*) AS total_customers,
    SUM(a.exited) AS churned_customers,
    ROUND((SUM(a.exited)::NUMERIC / COUNT(*)) * 100, 2) AS churn_rate,
    ct.churn_rate_total AS bank_avg_churn_rate
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
CROSS JOIN churn_total ct
GROUP BY c.geography, ct.churn_rate_total
ORDER BY churn_rate DESC;

-- QUESTION 2: What is the profile of customers who left vs those who stayed?
WITH churned AS (
    SELECT
        ROUND(AVG(c.age), 1) AS avg_age,
        ROUND(AVG(a.balance), 2) AS avg_balance,
        ROUND(AVG(a.credit_score), 1) AS avg_credit_score,
        ROUND(AVG(a.estimated_salary), 2) AS avg_salary,
        ROUND(AVG(a.num_of_products), 1) AS avg_products
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    WHERE a.exited = 1
),
retained AS (
    SELECT
        ROUND(AVG(c.age), 1) AS avg_age,
        ROUND(AVG(a.balance), 2) AS avg_balance,
        ROUND(AVG(a.credit_score), 1) AS avg_credit_score,
        ROUND(AVG(a.estimated_salary), 2) AS avg_salary,
        ROUND(AVG(a.num_of_products), 1) AS avg_products
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    WHERE a.exited = 0
)
SELECT
    'Churned' AS customer_status,
    avg_age, avg_balance, avg_credit_score, avg_salary, avg_products
FROM churned
UNION ALL
SELECT
    'Retained' AS customer_status,
    avg_age, avg_balance, avg_credit_score, avg_salary, avg_products
FROM retained;

-- QUESTION 3: Which customer segment churns the most?
WITH segmented AS (
    SELECT
        a.customer_id,
        a.exited,
        CASE
            WHEN a.balance >= 150000 THEN 'High Value'
            WHEN a.balance >= 75000 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS customer_segment
    FROM accounts a
)
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    SUM(exited) AS churned_customers,
    ROUND((SUM(exited)::NUMERIC / COUNT(*)) * 100, 2) AS churn_rate
FROM segmented
GROUP BY customer_segment
ORDER BY churn_rate DESC;

-- QUESTION 4: Do customers with credit score below their country's average churn more?
WITH country_avg AS (
    SELECT
        c.geography,
        ROUND(AVG(a.credit_score), 1) AS avg_credit_score
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    GROUP BY c.geography
)
SELECT
    c.geography,
    CASE
        WHEN a.credit_score < ca.avg_credit_score THEN 'Below Average'
        ELSE 'Above Average'
    END AS credit_score_group,
    COUNT(*) AS total_customers,
    SUM(a.exited) AS churned_customers,
    ROUND((SUM(a.exited)::NUMERIC / COUNT(*)) * 100, 2) AS churn_rate
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN country_avg ca ON c.geography = ca.geography
GROUP BY c.geography, credit_score_group
ORDER BY c.geography, churn_rate DESC;

-- QUESTION 5: Do unsatisfied or complaining customers churn more?
SELECT
    f.satisfaction_score,
    f.complain,
    COUNT(*) AS total_customers,
    SUM(a.exited) AS churned_customers,
    ROUND((SUM(a.exited)::NUMERIC / COUNT(*)) * 100, 2) AS churn_rate
FROM feedback f
JOIN accounts a ON f.customer_id = a.customer_id
GROUP BY f.satisfaction_score, f.complain
ORDER BY f.complain DESC, churn_rate DESC;

-- QUESTION 6: Which card type has the highest churn rate per country?
WITH churn_by_card AS (
    SELECT
        c.geography,
        a.card_type,
        COUNT(*) AS total_customers,
        SUM(a.exited) AS churned_customers,
        ROUND((SUM(a.exited)::NUMERIC / COUNT(*)) * 100, 2) AS churn_rate
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    GROUP BY c.geography, a.card_type
)
SELECT
    geography,
    card_type,
    total_customers,
    churned_customers,
    churn_rate,
    RANK() OVER (PARTITION BY geography ORDER BY churn_rate DESC) AS rank
FROM churn_by_card
ORDER BY geography, rank;