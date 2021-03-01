-- ------------------------------------------------------------------------------------------------
/* Представление, содержащее всю открытую информацию о пользователях: */

CREATE OR REPLACE VIEW vw_users_information AS
    SELECT 
		u.id AS user_id,
		CONCAT(u.last_name, ' ', u.first_name) AS user_name,
        CASE
			WHEN u.male = 'м' THEN 'мужской'
            ELSE 'женский'
            END AS gender,
		u.date_of_birth,
        TIMESTAMPDIFF(YEAR, u.date_of_birth, NOW()) AS age,
        u.e_mail,
        u.books_count
		FROM users u
	ORDER BY user_id;


-- ------------------------------------------------------------------------------------------------
/* Представление, содержащее информацию о книжных наименованиях: */ 
   
CREATE OR REPLACE VIEW vw_books_information AS
	WITH
	cat AS (SELECT 
			bc.id_books, 
			GROUP_CONCAT(c.name_category SEPARATOR ', ') AS b_cat
			FROM books_categories bc JOIN categories c ON bc.id_categories = c.id
			GROUP BY bc.id_books),
	auth AS (SELECT 
			ba.id_books, 
			GROUP_CONCAT(CONCAT(a.last_name, ' ', a.first_name) SEPARATOR ', ') AS b_auth
			FROM books_authors ba JOIN authors a ON ba.id_authors = a.id
			GROUP BY ba.id_books),
	lang AS (SELECT 
			bl.id_books, 
			GROUP_CONCAT(l.name_language SEPARATOR ', ') AS b_lang
			FROM books_languages bl JOIN languages l ON bl.id_languages = l.id
			GROUP BY bl.id_books)
	SELECT
		b.id,
		b.name_book,
        b.ISBN,
        b.anotation,
        b.publish_year,
        p.name_publisher,
		cat.b_cat AS category,
		auth.b_auth AS author,
		lang.b_lang AS `language`,
        b.book_count
		FROM
			books b
		LEFT JOIN
			publishers p
            ON b.id_publishers = p.id
		LEFT JOIN
			cat
			ON cat.id_books = b.id
		LEFT JOIN
			auth
			ON auth.id_books = b.id
		LEFT JOIN
			lang
			ON lang.id_books = b.id
	ORDER BY b.id;


-- ------------------------------------------------------------------------------------------------
/* Представление, содержащее список желаемых книг пользователей: */

CREATE OR REPLACE VIEW vw_wishlists_information AS
	WITH
	auth AS (SELECT 
			ba.id_books, 
			GROUP_CONCAT(CONCAT(a.last_name, ' ', a.first_name) SEPARATOR ', ') AS b_auth
			FROM books_authors ba JOIN authors a ON ba.id_authors = a.id
			GROUP BY ba.id_books)
	SELECT
		CONCAT(u.last_name, ' ', u.first_name) AS user_name,
		u.id AS user_id,
		GROUP_CONCAT(CONCAT(b.name_book, ' (', auth.b_auth, '): ', uw.wish_count) SEPARATOR ',\n') AS books_information,
		SUM(uw.wish_count) AS total_books
		FROM
			books b
		JOIN
			users_wishlists uw
			ON b.id = uw.id_books
		JOIN
			auth
			ON auth.id_books = b.id
		RIGHT JOIN
			users u
			ON uw.id_users = u.id
	GROUP BY u.id
	ORDER BY u.last_name;