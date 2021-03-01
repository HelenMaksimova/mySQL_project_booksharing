
-- Все примеры выполнения убраны в комментарии, чтобы не выполнялись при создании функций, процедур и триггеров

USE booksharing;

DELIMITER //

/* ************************************************** */
-- -------------------- ФУНКЦИИ ----------------------
/* ************************************************** */

-- ---------------------------------------------------------------------
-- Функция дря расчёта рейтинга книги

DROP FUNCTION IF EXISTS f_book_rating//
CREATE FUNCTION f_book_rating(b_id BIGINT UNSIGNED)
	RETURNS FLOAT READS SQL DATA
	BEGIN
		DECLARE v_rating FLOAT;
        
        SET v_rating = 
			(SELECT rate FROM 
				(SELECT 
					AVG(CASE
						WHEN br.rating = 'Awful' THEN 0
                        WHEN br.rating = 'Bad' THEN 1
                        WHEN br.rating = 'Normal' THEN 2
                        WHEN br.rating = 'Good' THEN 3
                        ELSE 4 END) AS rate
					FROM books_rating br
                    GROUP BY br.id_books
                    HAVING br.id_books = b_id)
                    AS b_rate);

		RETURN ROUND(v_rating, 2);
	END//


-- ---------------------------------------------------------------------
-- Функция дря расчёта количества баллов пользователя 
-- (разница между внесёнными и полученными книгами)
    
DROP FUNCTION IF EXISTS f_user_points_calculate//
CREATE FUNCTION f_user_points_calculate(v_user_id BIGINT UNSIGNED)
	RETURNS INT READS SQL DATA
	BEGIN
		DECLARE v_count_up, v_count_down, v_result INT DEFAULT 0;
        SET v_count_up = (SELECT COUNT(*) FROM books_on_stock WHERE received_from = v_user_id);
        SET v_count_down = (SELECT COUNT(*) FROM books_on_stock WHERE received_by = v_user_id);
        SET v_result = v_count_up - v_count_down;
        IF v_result < 0 
		THEN 
			SET v_result = 0;
		END IF;
        RETURN v_result;
	END//


-- ---------------------------------------------------------------------
-- Функция дря расчёта количества книг в наличии
-- (разница между внесёнными и выданными книгами)

DROP FUNCTION IF EXISTS f_book_count_calculate//
CREATE FUNCTION f_book_count_calculate(v_book_id BIGINT UNSIGNED)
	RETURNS INT READS SQL DATA
	BEGIN
		DECLARE v_count_up, v_count_down, v_result INT DEFAULT 0;
        SET v_count_up = (SELECT COUNT(*) FROM books_on_stock WHERE id_books = v_book_id);
        SET v_count_down = (SELECT COUNT(*) FROM books_on_stock WHERE id_books = v_book_id AND received_by IS NOT NULL);
        SET v_result = v_count_up - v_count_down;
        IF v_result < 0 
		THEN 
			SET v_result = 0;
		END IF;
        RETURN v_result;
	END//


-- ---------------------------------------------------------------------
-- Функция дря расчёта количества зарезервированных (и не полученных)
-- пользователем книг

DROP FUNCTION IF EXISTS f_user_reserved_count//
CREATE FUNCTION f_user_reserved_count(v_user_id BIGINT UNSIGNED)
	RETURNS INT READS SQL DATA
	BEGIN
		DECLARE v_result INT;
        SET v_result = 
			(SELECT COUNT(*) 
            FROM books_on_stock 
            WHERE reserved_by = v_user_id AND (received_by <> v_user_id OR received_by IS NULL));
		RETURN v_result;
	END//


/* ************************************************** */
-- --------------- ХРАНИМЫЕ ПРОЦЕДУРЫ ----------------
/* ************************************************** */

-- ---------------------------------------------------------------------
-- Процедура добавления новой позиции в каталог книг

DROP PROCEDURE IF EXISTS sp_add_book//
CREATE PROCEDURE sp_add_book (v_name_book VARCHAR(255), 
								v_ISBN VARCHAR(20), 
                                v_anotation TEXT, 
                                v_publish_year YEAR, 
                                v_id_publishers BIGINT UNSIGNED,
                                v_category_id SMALLINT UNSIGNED,
                                v_author_id BIGINT UNSIGNED,
                                v_language_id SMALLINT UNSIGNED)
BEGIN
	
    DECLARE v_error BIT DEFAULT 0;
	DECLARE v_error_code VARCHAR(100);
    DECLARE v_error_msg VARCHAR(255);
    
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
	BEGIN
 		SET v_error = 1;
        GET STACKED DIAGNOSTICS CONDITION 1
			v_error_code = RETURNED_SQLSTATE, v_error_msg = MESSAGE_TEXT;
	END;
    
    START TRANSACTION;
    
		INSERT INTO books (`name_book`, `ISBN`, `anotation`, `publish_year`, `id_publishers`)
			VALUES(v_name_book, v_ISBN, v_anotation, v_publish_year, v_id_publishers);
		
        INSERT INTO books_authors (id_books, id_authors)
			VALUES (last_insert_id(), v_author_id);
		
		INSERT INTO books_languages (id_books, id_languages)
			VALUES (last_insert_id(), v_language_id);
		
		INSERT INTO books_categories (id_books, id_categories)
			VALUES (last_insert_id(), v_category_id);
		
        IF v_error = 1
        THEN
            ROLLBACK;
			SELECT CONCAT('Операция отменена. Ошибка ', v_error_code, ': ', v_error_msg) AS `error`;
        ELSE
			COMMIT;
            SELECT 'Операция произведена успешно' AS `success`;
		END IF;
	
END//

/*ПРИМЕРЫ:

Вставка валидных данных:

	CALL sp_add_book('New book', NULL, 'Наверное, очень интересная книга. Но это не точно.', 2021, 13, 6, 16, 8);

Вставка ошибочных данных (указан несуществующий id автора):

	CALL sp_add_book('New book', NULL, 'Наверное, очень интересная книга. Но это не точно.', 2021, 13, 6, 22, 8);

Проверочная выборка:

	SELECT id, name_book, ISBN, anotation, publish_year, name_publisher, category, author, language 
		FROM vw_books_information
		ORDER BY id DESC
		LIMIT 20;
*/


-- ---------------------------------------------------------------------
-- Процедура, выводящая все комментарии заданного пользователя

DROP PROCEDURE IF EXISTS sp_user_comments//
CREATE PROCEDURE sp_user_comments (v_user_id BIGINT UNSIGNED)
	BEGIN
		SELECT 
			CONCAT('Пользователь: ', user_name) AS comments, 
			CONCAT('ID: ', v_user_id) AS book, 
			NULL AS book_author
			FROM 
				vw_users_information 
			WHERE user_id = v_user_id
			
		UNION
		
		SELECT 
			uc.user_comment,
			vbinf.name_book,
			vbinf.author
			FROM
				users_comments uc
			JOIN
				vw_books_information vbinf
				ON uc.id_books = vbinf.id
		WHERE uc.id_users = v_user_id;
	END//

/*ПРИМЕРЫ:

	CALL sp_user_comments(5);

	CALL sp_user_comments(2);

*/

-- ---------------------------------------------------------------------
-- Процедура, обновляющая данные о количестве имеющихся экземпляров заданной книги
   
DROP PROCEDURE IF EXISTS sp_book_count_update//
CREATE PROCEDURE sp_book_count_update (v_book_id BIGINT UNSIGNED)
	BEGIN
		UPDATE books
			SET book_count = f_book_count_calculate(v_book_id)
		WHERE id = v_book_id;
    END//
-- вызывается в триггерах


-- ---------------------------------------------------------------------
-- Процедура, обновляющая данные о количестве баллов заданного пользователя
   
DROP PROCEDURE IF EXISTS sp_user_points_update//
CREATE PROCEDURE sp_user_points_update (v_user_id BIGINT UNSIGNED)
	BEGIN
		UPDATE users
			SET books_count = f_user_points_calculate(v_user_id)
		WHERE id = v_user_id;
    END//
-- вызывается в триггерах


/* ************************************************** */
-- -------------------- ТРИГГЕРЫ ----------------------
/* ************************************************** */

-- ---------------------------------------------------------------------
-- Триггер, проверяющий перед апдейтом таблицы книг в наличии достаточно ли 
-- у пользователя баллов для получеия или бронирования книги

DROP TRIGGER IF EXISTS tr_books_on_stock_update//
CREATE TRIGGER tr_books_on_stock_update BEFORE UPDATE ON books_on_stock
	FOR EACH ROW
	BEGIN
		DECLARE v_user_state INT;
        
		SET v_user_state = f_user_points_calculate(NEW.reserved_by);
		IF NEW.reserved_by IS NOT NULL  
			AND (OLD.reserved_by IS NULL OR OLD.reserved_by <> NEW.reserved_by) 
			AND v_user_state <= f_user_reserved_count(NEW.reserved_by)
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'UPDATE canceled: the user has no points enough to reserve books';
		END IF;
        
		SET v_user_state = f_user_points_calculate(NEW.received_by);
		IF NEW.received_by IS NOT NULL AND v_user_state = 0
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'UPDATE canceled: the user has no points enough to receive books';
		END IF;
        
	END//

/*ПРИМЕРЫ:

Резервирование книг:

	SELECT user_id, books_count FROM vw_users_information WHERE user_id = 1;

	Резервируем до тех пор, пока количество баллов пользователя (на данный мемент) больше 
	или равно количеству резервируемых книг:

	UPDATE books_on_stock
	SET reserved_by = 1
	WHERE id IN (1, 2);

	Если попробуем зарезервировать ещё, получим отмену операции:

	UPDATE books_on_stock
	SET reserved_by = 1
	WHERE id = 3;
    
    Проверочная выборка:
    
    SELECT id, id_books, reserved_by, received_by
    FROM books_on_stock
    ORDER BY id
    LIMIT 20;

Выдача книг:
	
    SELECT user_id, books_count FROM vw_users_information WHERE user_id = 1;
    
    Выдаём, пока у пользователя достаточно баллов:
    
	UPDATE books_on_stock
	SET received_by = 1
	WHERE id IN (1, 2);
    
    Если выдать пользователю, у которого 0 баллов, получим отмену операции:
    
    SELECT user_id, books_count FROM vw_users_information WHERE user_id = 5;
    
    UPDATE books_on_stock
	SET received_by = 5
	WHERE id = 3;
    
	Проверочная выборка:
    
    SELECT id, id_books, reserved_by, received_by
    FROM books_on_stock
    ORDER BY id
    LIMIT 20;
*/


-- ---------------------------------------------------------------------
-- Триггер после вставки новой строки в таблицу книг в наличии
-- запускает хранимые процедуры обновления количества экземпляров книги
-- и количества баллов пользователя, отдавшего книгу
    
DROP TRIGGER IF EXISTS tr_books_on_stock_insert//
CREATE TRIGGER tr_books_on_stock_insert AFTER INSERT ON books_on_stock
	FOR EACH ROW
	BEGIN
		CALL sp_book_count_update(NEW.id_books);
        CALL sp_user_points_update(NEW.received_from);
    END//

/*ПРИМЕРЫ:

У пользователя 5 недостаточно баллов для получения или резервирования книг:

	SELECT user_id, books_count FROM vw_users_information WHERE user_id = 5;

Путь этот пользователь принёс в пункт обмена две книги:
	
    INSERT INTO books_on_stock (id_books, received_from)
		VALUES
        (2, 5),
        (3, 5);

Теперь этому пользователю начислилось два балла:

	SELECT user_id, books_count FROM vw_users_information WHERE user_id = 5;
*/


-- ---------------------------------------------------------------------
-- Триггер после обновления таблицы книг в наличии
-- запускает хранимые процедуры обновления количества экземпляров книги
-- и количества баллов пользователя, получившего книгу

DROP TRIGGER IF EXISTS tr_books_on_stock_after_update//
CREATE TRIGGER tr_books_on_stock_after_update AFTER UPDATE ON books_on_stock
	FOR EACH ROW
	BEGIN
		CALL sp_book_count_update(NEW.id_books);
		CALL sp_user_points_update(NEW.received_by);
    END//

/*ПРИМЕРЫ:

Теперь у пользователя 5 есть баллы для получения книг:

	SELECT user_id, books_count FROM vw_users_information WHERE user_id = 5;

Пусть он получит одну:
	
    UPDATE books_on_stock
	SET received_by = 5
	WHERE id = 3;

Количество баллов пользователя уменьшилось:

	SELECT user_id, books_count FROM vw_users_information WHERE user_id = 5;


Теперь посмотрим на количество книг в наличии. Вот выборка первых пяти наименований:
	
    SELECT id, name_book, book_count FROM vw_books_information ORDER BY id LIMIT 5;

Пусть в обменный пункт сдали несколько книг:

    INSERT INTO books_on_stock (id_books, received_from)
		VALUES
        (4, 1),
        (5, 1),
		(3, 2),
        (5, 2);

Количество книг в наличии увеличилось:

	SELECT id, name_book, book_count FROM vw_books_information ORDER BY id LIMIT 5;

Пусть кто-нибудь забрал книгу (id книжного наименования 3, id экземпляра 155):
	
	UPDATE books_on_stock
	SET received_by = 5
	WHERE id = 155;
    
Количество книг в наличии уменьшилось:

	SELECT id, name_book, book_count FROM vw_books_information ORDER BY id LIMIT 5;
*/

DELIMITER ;