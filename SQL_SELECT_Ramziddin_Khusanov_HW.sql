

--1 
-- The marketing team needs a list of animation movies between 2017 and 2019 to 
-- promote family-friendly content in an upcoming season in stores. Show all animation 
-- movies released during this period with rate more than 1, sorted alphabetically
SELECT f.title
FROM film AS f
JOIN film_category AS fc ON fc.film_id = f.film_id
JOIN category AS c ON c.category_id = fc.category_id
WHERE c.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title;

--2 
-- The finance department requires a report on store performance to assess profitability and plan 
-- resource allocation for stores after March 2017. Calculate the revenue earned by each rental store 
-- after March 2017 (since April) (include columns: address and address2 – as one column, revenue)
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

--3
-- The marketing department in our stores aims to identify the most successful actors since 2015 to 
-- boost customer interest in their films. Show top-5 actors by number of movies (released after 2015) 
-- they took part in (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
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
--The marketing team needs to track the production trends of Drama, Travel, and Documentary films to 
-- inform genre-specific marketing strategies. Show number of Drama, Travel, Documentary per year 
-- (include columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies),
-- sorted by release year in descending order. Dealing with NULL values is encouraged)
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
-- The HR department aims to reward top-performing employees in 2017 
-- with bonuses to recognize their contribution to stores revenue. 
-- Show which three employees generated the most revenue in 2017? 


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
-- The management team wants to identify the most popular movies and their target audience age groups 
-- to optimize marketing efforts. Show which 5 movies were rented more than others (number of rentals), 
-- and what's the expected age of the audience for these movies? To determine expected age please use 
-- 'Motion Picture Association film rating system'

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
-- The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable 
-- career breaks for targeted promotional campaigns, highlighting their comebacks or consistent appearances
-- to engage customers with nostalgic or reliable film stars

-- V1: gap between the latest release_year and current year per each actor;


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

-- The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable 
-- career breaks for targeted promotional campaigns, highlighting their comebacks or consistent appearances
-- to engage customers with nostalgic or reliable film stars

-- V2: gaps between sequential films per each actor; 
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




