select title, rental_rate from film where title = 'TRAIN BUNCH' 
or title = 'MIXED DOORS' or title = 'FREEDOM CLEOPATRA'
or title = 'HARDLY ROBBERS'
or title =  'BRAVEHEART HUMAN'
order by rental_rate;


select title, sum(amount) from rental r 
join inventory i on i.inventory_id = r.inventory_id
join film f on f.film_id = i.film_id
join payment p on p.rental_id = r.rental_id
group by title
order by sum(amount) desc
;

-- Maximum store revenue in 2017
SELECT MAX(store_revenue) AS max_revenue_2017
FROM (
  SELECT i.store_id,
         ROUND(SUM(p.amount), 2) AS store_revenue
  FROM inventory i
  JOIN rental   r ON r.inventory_id = i.inventory_id
  JOIN payment  p ON p.rental_id    = r.rental_id
  WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
  GROUP BY i.store_id
) t;



-- 1 
SELECT f.title
FROM film AS f
JOIN film_category AS fc ON fc.film_id = f.film_id
JOIN category AS c ON c.category_id = fc.category_id
WHERE c.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title;


-- 2
SELECT i.store_id,
       CONCAT_WS(' ', a.address, a.address2) AS store_address,
       ROUND(SUM(p.amount), 2)              AS revenue
FROM inventory AS i
JOIN store     AS s  ON s.store_id = i.store_id
JOIN address   AS a  ON a.address_id = s.address_id
JOIN rental    AS r  ON r.inventory_id = i.inventory_id
JOIN payment   AS p  ON p.rental_id    = r.rental_id
WHERE p.payment_date >= DATE '2017-04-01'
GROUP BY i.store_id, CONCAT_WS(' ', a.address, a.address2)
ORDER BY revenue DESC;

-- 3
SELECT a.first_name,
       a.last_name,
       COUNT(DISTINCT fa.film_id) AS number_of_movies
FROM actor AS a
JOIN film_actor AS fa ON fa.actor_id = a.actor_id
JOIN film AS f        ON f.film_id   = fa.film_id
WHERE f.release_year > 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC, a.last_name, a.first_name
LIMIT 5;

-- 4
SELECT f.release_year,
       COALESCE(SUM(CASE WHEN c.name = 'Drama'        THEN 1 END), 0) AS number_of_drama_movies,
       COALESCE(SUM(CASE WHEN c.name = 'Travel'       THEN 1 END), 0) AS number_of_travel_movies,
       COALESCE(SUM(CASE WHEN c.name = 'Documentary'  THEN 1 END), 0) AS number_of_documentary_movies
FROM film AS f
JOIN film_category AS fc ON fc.film_id = f.film_id
JOIN category      AS c  ON c.category_id = fc.category_id
WHERE c.name IN ('Drama','Travel','Documentary')
GROUP BY f.release_year
ORDER BY f.release_year DESC;



-- 2.1

WITH p17 AS (
  SELECT
      p.staff_id,
      i.store_id,                 -- store of the rental for that payment
      p.amount,
      p.payment_date
  FROM payment  p
  JOIN rental   r ON r.rental_id    = p.rental_id
  JOIN inventory i ON i.inventory_id = r.inventory_id
  WHERE p.payment_date >= DATE '2017-01-01'
    AND p.payment_date <  DATE '2018-01-01'
),
rev AS (                      -- total 2017 revenue per staff
  SELECT staff_id, SUM(amount) AS revenue_2017
  FROM p17
  GROUP BY staff_id
),
last_store AS (               -- the last store a staff worked in (by last 2017 payment)
  SELECT DISTINCT ON (staff_id)
         staff_id, store_id
  FROM p17
  ORDER BY staff_id, payment_date DESC
)
SELECT
  s.staff_id,
  s.first_name,
  s.last_name,
  ls.store_id,
  CONCAT_WS(' ', a.address, a.address2) AS store_address,
  ROUND(r.revenue_2017, 2)              AS revenue_2017
FROM rev r
JOIN staff      s  ON s.staff_id   = r.staff_id
JOIN last_store ls ON ls.staff_id  = r.staff_id
JOIN store      st ON st.store_id  = ls.store_id
JOIN address    a  ON a.address_id = st.address_id
ORDER BY revenue_2017 DESC, s.last_name, s.first_name
LIMIT 3;



-- 2.2

-- Top 5 most-rented films + expected audience age (MPAA)
SELECT
    f.title,
    f.rating,
    COUNT(r.rental_id) AS rentals,
    CASE f.rating
        WHEN 'G'     THEN 0     -- all ages
        WHEN 'PG'    THEN 10
        WHEN 'PG-13' THEN 13
        WHEN 'R'     THEN 17
        WHEN 'NC-17' THEN 18
        ELSE NULL
    END AS expected_age
FROM film f
JOIN inventory i ON i.film_id = f.film_id
JOIN rental   r ON r.inventory_id = i.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY rentals DESC, f.title
LIMIT 5;


-- 3.v1

WITH actor_last_film AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        MAX(f.release_year) AS last_release_year
    FROM actor a
    JOIN film_actor fa ON fa.actor_id = a.actor_id
    JOIN film f ON f.film_id = fa.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT
    first_name,
    last_name,
    last_release_year,
    (EXTRACT(YEAR FROM CURRENT_DATE) - last_release_year) AS inactivity_years
FROM actor_last_film
ORDER BY inactivity_years DESC
LIMIT 10;



-- 3.v2

WITH actor_films AS (
    SELECT
        a.actor_id,
        a.first_name,
        a.last_name,
        f.release_year
    FROM actor a
    JOIN film_actor fa ON fa.actor_id = a.actor_id
    JOIN film f ON f.film_id = fa.film_id
),
ordered_films AS (
    SELECT
        actor_id,
        first_name,
        last_name,
        release_year,
        LAG(release_year) OVER (PARTITION BY actor_id ORDER BY release_year) AS prev_year
    FROM actor_films
),
gaps AS (
    SELECT
        actor_id,
        first_name,
        last_name,
        release_year,
        prev_year,
        (release_year - prev_year) AS year_gap
    FROM ordered_films
    WHERE prev_year IS NOT NULL
)
SELECT
    first_name,
    last_name,
    MAX(year_gap) AS max_inactivity_gap
FROM gaps
GROUP BY actor_id, first_name, last_name
ORDER BY max_inactivity_gap DESC
LIMIT 10;




