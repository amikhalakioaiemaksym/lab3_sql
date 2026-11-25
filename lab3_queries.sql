SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
USE credit_bank_lab2;

SELECT
    name        AS `Вид кредиту`,
    annual_rate AS `Річна ставка, %`,
    term_days   AS `Термін, днів`,
    ROUND(annual_rate * term_days / 365, 2)          AS `Переплата, %`,
    ROUND(100000 * annual_rate / 100 * term_days / 365, 2) AS `Переплата на 100000`
FROM credit_type
ORDER BY annual_rate DESC, term_days ASC;

SELECT
    name AS `Клієнт`,
    COALESCE(NULLIF(TRIM(phone), ''), 'немає контакту') AS `Телефон`,
    COALESCE(NULLIF(CONCAT_WS(' ', contact_last_name, contact_first_name,
                              contact_middle_name), ''),
             'немає контакту') AS `Контактна особа`
FROM client
WHERE NULLIF(TRIM(phone), '') IS NULL
   OR NULLIF(TRIM(contact_last_name), '') IS NULL;


SET @threshold = 500000;

SELECT *
FROM (
    SELECT
        c.credit_id  AS `Номер кредиту`,
        c.amount     AS `Сума кредиту`,
        c.issue_date AS `Дата видачі`,
        DATEDIFF(
            CASE WHEN COALESCE(SUM(r.payment_amount), 0) >= c.amount
                 THEN MAX(r.payment_date) ELSE CURDATE() END,
            c.issue_date) AS `Фактичний термін, днів`,
        ROUND(c.amount * (1 + t.annual_rate / 100 *
            DATEDIFF(
                CASE WHEN COALESCE(SUM(r.payment_amount), 0) >= c.amount
                     THEN MAX(r.payment_date) ELSE CURDATE() END,
                c.issue_date) / 365), 2) AS `Сума до повернення`
    FROM credit c
    JOIN credit_type t    ON t.credit_type_id = c.credit_type_id
    LEFT JOIN repayment r ON r.credit_id = c.credit_id
    GROUP BY c.credit_id, c.amount, c.issue_date, t.annual_rate
) AS q
WHERE `Сума до повернення` > @threshold
ORDER BY `Сума до повернення` DESC;


SET @min_sum = 50000, @max_sum = 500000, @rate = 15;
SET @terms = '90,180,365';   -- без пробілів

SELECT c.credit_id, c.amount, t.name AS credit_type,
       t.annual_rate, t.term_days
FROM credit c
JOIN credit_type t ON t.credit_type_id = c.credit_type_id
WHERE (c.amount BETWEEN @min_sum AND @max_sum AND t.annual_rate > @rate)
   OR (FIND_IN_SET(t.term_days, @terms) = 0
       AND NOT EXISTS (SELECT 1 FROM repayment r
                       WHERE r.credit_id = c.credit_id
                         AND r.penalty_amount > 0))
ORDER BY c.credit_id;


SET @fragment = 'Агро';

SELECT CONCAT(o.name, ' «', c.name, '»') AS `Клієнт`
FROM client c
JOIN ownership_type o ON o.ownership_type_id = c.ownership_type_id
WHERE c.name LIKE CONCAT('%', @fragment, '%')
  AND CHAR_LENGTH(o.name) = 3;


SET @days = 30;

SELECT
    c.credit_id,
    cl.name AS client_name,
    c.amount,
    DATE_ADD(c.issue_date, INTERVAL t.term_days DAY) AS due_date,
    DATEDIFF(DATE_ADD(c.issue_date, INTERVAL t.term_days DAY),
             CURDATE()) AS `днів_до_погашення`
FROM credit c
JOIN client cl     ON cl.client_id = c.client_id
JOIN credit_type t ON t.credit_type_id = c.credit_type_id
WHERE DATEDIFF(DATE_ADD(c.issue_date, INTERVAL t.term_days DAY),
               CURDATE()) BETWEEN 0 AND @days
  AND c.amount > (SELECT COALESCE(SUM(r.payment_amount), 0)
                  FROM repayment r WHERE r.credit_id = c.credit_id)
ORDER BY `днів_до_погашення` ASC;


SELECT `Клієнт`, `Сума`, `Клас`
FROM (
    SELECT cl.name AS `Клієнт`,
           c.amount AS `Сума`,
           CASE
               WHEN c.amount < 100000  THEN 'мікрокредит'
               WHEN c.amount < 1000000 THEN 'малий'
               ELSE 'великий'
           END AS `Клас`
    FROM credit c
    JOIN client cl ON cl.client_id = c.client_id
) AS q
ORDER BY FIELD(`Клас`, 'мікрокредит', 'малий', 'великий'), `Сума` DESC;


SET @skip1 = 'Овердрафт', @skip2 = 'Експрес';

SELECT DISTINCT t.name AS `Вид кредиту`
FROM credit_type t
JOIN credit c ON c.credit_type_id = t.credit_type_id
WHERE t.name NOT IN (@skip1, @skip2)
ORDER BY t.name
LIMIT 5 OFFSET 5;
