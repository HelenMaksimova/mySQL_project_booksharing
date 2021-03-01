USE booksharing;

-- ------------------------------------------------------------------------------------------------
-- Сколько наименований книг имеется у каждого издетельства:
SELECT 
	pub.name_publisher, 
    COUNT(b.id) AS total_books
	FROM 
		publishers pub 
	LEFT JOIN 
        books b
		ON b.id_publishers = pub.id
GROUP BY pub.name_publisher
ORDER BY total_books DESC;


-- ------------------------------------------------------------------------------------------------
-- Сколько книг в наличии имеется для каждого издетельства:
SELECT 
	pub.name_publisher, 
	COUNT(b.id) AS total_books
	FROM 
		books_on_stock bos 
	JOIN 
		books b 
		ON b.id = bos.id_books 
	RIGHT JOIN 
		publishers pub 
		ON b.id_publishers = pub.id
GROUP BY pub.name_publisher WITH ROLLUP
ORDER BY pub.name_publisher;


-- ------------------------------------------------------------------------------------------------	
-- Список пользователей, у которых нет желаемых книг:
SELECT 
    CONCAT(u.last_name, ' ', u.first_name) AS user_name,
    u.id AS user_id
FROM users_wishlists uw RIGHT JOIN users u ON uw.id_users = u.id
WHERE uw.id_users IS NULL
GROUP BY u.id
ORDER BY u.last_name;


-- ------------------------------------------------------------------------------------------------  
-- Список категорий, в которых нет ни одной книги:
SELECT 
	c.name_category,
    c.id
	FROM 
		categories c
	LEFT JOIN
		books_categories bc
		ON c.id = bc.id_categories
	WHERE bc.id_books IS NULL;


-- ------------------------------------------------------------------------------------------------
-- Список книг, имеющих одинаковое название:
SELECT 
	b.id, 
    b.name_book,
    GROUP_CONCAT(DISTINCT CONCAT(a.last_name, ' ', a.first_name) SEPARATOR ', ') AS authors
	FROM 
		books b
	LEFT JOIN
		books_authors ba
        ON b.id = ba.id_books
	LEFT JOIN 
		authors a
		ON ba.id_authors = a.id
WHERE b.name_book IN 
	(SELECT name_book FROM books GROUP BY name_book HAVING COUNT(name_book) > 1)
GROUP BY b.id
ORDER BY b.name_book;


-- ------------------------------------------------------------------------------------------------	    
-- Три категории, в которых находятся наиболее востребованные книги:
SELECT
	c.id,
	c.name_category,
	SUM(uw.wish_count) AS total
	FROM
		categories c
	JOIN
		books_categories bc
		ON c.id = bc.id_categories
	JOIN
		books b
        ON bc.id_books = b.id
	JOIN 
		users_wishlists uw
        ON uw.id_books = b.id
GROUP BY c.id
ORDER BY total DESC
LIMIT 3;


-- ------------------------------------------------------------------------------------------------
-- Книги, наиболее востребованные (имеющие больше 1 пожелания) пользователями младше 40 лет:
WITH
auth AS (SELECT 
		ba.id_books, 
        GROUP_CONCAT(CONCAT(a.last_name, ' ', a.first_name) SEPARATOR ', ') AS b_auth
        FROM books_authors ba JOIN authors a ON ba.id_authors = a.id
        GROUP BY ba.id_books)
SELECT
	b.id,
	b.name_book,
    auth.b_auth AS author,
    SUM(uw.wish_count) AS total
    FROM
		books b
	LEFT JOIN
		auth
        ON b.id = auth.id_books
	JOIN
		users_wishlists uw
        ON uw.id_books = b.id
	JOIN users u
		ON u.id = uw.id_users
WHERE TIMESTAMPDIFF(YEAR, u.date_of_birth, NOW()) < 40 
GROUP BY b.id
HAVING total > 1
ORDER BY total DESC;


-- ------------------------------------------------------------------------------------------------
-- Книги какой категории получили наибольшее количество комментариев:
SELECT 
	c.id,
    c.name_category,
    COUNT(c.id) AS total_comments
    FROM
		categories c
	JOIN
		books_categories bc
        ON c.id = bc.id_categories
	JOIN
		users_comments uc
        ON bc.id_books = uc.id_books
GROUP BY c.id
ORDER BY total_comments DESC
LIMIT 1;


-- ------------------------------------------------------------------------------------------------
-- Книги какого автора имеют наивысший рейтинг (задействована пользовательская функция f_book_rating):
SELECT 
	a.id AS author_id,
	CONCAT(a.last_name, ' ', a.first_name) AS author_name,
	ROUND(AVG(f_book_rating(ba.id_books)), 2) AS total_rating
    FROM 
		authors a
	JOIN
		books_authors ba
        ON a.id = ba.id_authors
GROUP BY author_id
ORDER BY total_rating DESC
LIMIT 1;