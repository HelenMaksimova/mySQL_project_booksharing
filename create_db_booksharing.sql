/*Для предварительной проверки*/

/* ************************************** */
/* ****** БАЗА ДАННЫХ BOOKSHARING ****** */
/* ************************************** */

/*
База данных предназначена для хранения информации сервиса по обмену книгами.
Имеется некий обменный пункт, куда можно сдать ненужные книги и забрать что-то
интересующее взамен.

В базе реализован следующий функционал:
	- общий каталог книжных наименований;
	- каталоги книжных категорий, авторов, издательств и языков;
	- перечень имеющихся в наличии экземпляров книг;
	- информация о постоянных клиентах;
	- подсчёт полученных и отданных клиентами книг;
    - перечень книг, которые клиенты хотели бы получить;
	- возможность резервирования интересующих книг;
    - рейтинг книжных наименований;
    - комментирование книжных наименований.

Имеютя следующие таблицы (связи в данном описании обозначены для крупных таблиц):

`authors` - каталог авторов книг (справочник);
 
`categories` - каталог категорий книг (справочник); 

`publishers` - каталог издательств (справочник); 

`languages` - каталог языков (справочник);

`books_photos` - таблица со ссылками на фотографии книг;

`books` - каталог книжных наименований 
	(имеет дополнительный столбец с количеством книг в наличии для более быстрого доступа к этим данным)
    (имеется функция для подсчёта количества книг в наличии)
	(ISBN - это уникальный номер книги, но не экземпляра, у некоторых изданий отсутствует)
    (связана со справочниками языков, авторов и категорий по типу 'многие-ко-многим', 
    со справочником издательств по типу 'многие-к-одному',  а также с таблицей фотографий книг по типу 'один-ко-многим');
    
`books_on_stock` - таблица книг в наличии, фактически, основная таблица базы.
	(содержит информацию о том, какой пользователь какую книгу сдал, а также поле для резервирования книги и поле для передачи книги пользователю)
    (на эту таблицу повешено три триггера для реализации функционала обновления данных при поступлении новых книг или при передачи их пользователям,
    а также проверки возможности выдать или зарезервировать книгу - исходя из личного счёта пользователя)
    (имеется функции для подсчёта количества зарезервированных пользователем книг и личного счёта пользователя)
    (функционал архивирования данных и чистки не разрабатывался (пока что))
    (связана с каталогом книжных наименований и таблицей пользователей по типу 'многие-к-одному');
 
`books_rating` - таблица рейтинга книжных наименований;
	(имеет составной первичный ключ из id пользователя и id книги)
	(рейтинг реализован через тип данных ENUM и содержит пять значений оценки - от ужасной до превосходной)
    (так же имеется функция для подсчёта некоего численного значения рейтинга для определённого книжного наименования);

`users` - таблица пользователей, имеет характерные поля с личными данными
	(имеет дополнительный столбец с личным счётом пользователя для более быстрого доступа к этим данным);

`users_comments` - таблица комментариев пользователей к книгам
	(связана с таблицами книжных наименований и пользователей типу 'многие-к-одному');

`users_wishlists` - таблица книжных наименований, которые пользователи хотели бы получить
	(имеет составной первичный ключ из id пользователя и id книги)
    (имеет поле желаемого количества экземпляров);

`books_authors` - реализация связи 'многие-ко-многим', составной первичный ключ; 

`books_categories` - реализация связи 'многие-ко-многим', составной первичный ключ;

`books_languages` - реализация связи 'многие-ко-многим', составной первичный ключ.

*/


-- ---------------------------------------------------------------------------------
-- СКРИПТ СОЗДАНИЯ БАЗЫ ДАННЫХ

DROP DATABASE IF EXISTS booksharing;

CREATE DATABASE booksharing;

USE booksharing;

CREATE TABLE categories (
	id SMALLINT UNSIGNED UNIQUE AUTO_INCREMENT PRIMARY KEY,
	name_category VARCHAR(255) NOT NULL DEFAULT 'Прочее'
) COMMENT = 'Справочник каталогов книг';

CREATE TABLE languages (
	id SMALLINT UNSIGNED AUTO_INCREMENT UNIQUE PRIMARY KEY,
	name_language VARCHAR(150) NOT NULL DEFAULT 'Неизвестно'
) COMMENT = 'Справочник языков';

CREATE TABLE authors (
	id SERIAL PRIMARY KEY,
	last_name VARCHAR(100) NOT NULL DEFAULT '',
	first_name VARCHAR(100) NOT NULL DEFAULT '',
	author_information JSON,
	INDEX (last_name, first_name)
) COMMENT = 'Справочник авторов книг';

CREATE TABLE publishers (
	id SERIAL PRIMARY KEY,
	name_publisher VARCHAR(150) NOT NULL DEFAULT 'Неизвестно',
	publisher_information JSON,
	INDEX (name_publisher)
) COMMENT = 'Справочник издательств';

CREATE TABLE users (
	id SERIAL PRIMARY KEY,
	last_name VARCHAR(100) NOT NULL DEFAULT 'Неизвестно',
	first_name VARCHAR(100) NOT NULL DEFAULT 'Неизвестно',
	male CHAR(1),
	date_of_birth DATE,
	books_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	e_mail VARCHAR(100) NOT NULL UNIQUE,
	user_password_hash VARCHAR(100) NOT NULL,
	registred_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT = 'Таблица пользователей';

CREATE TABLE books (
	id SERIAL PRIMARY KEY,
	name_book VARCHAR(255) NOT NULL DEFAULT 'Без названия',
	ISBN VARCHAR(20) DEFAULT NULL,
	anotation TEXT,
	publish_year YEAR NOT NULL DEFAULT '0000',
	book_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	id_publishers BIGINT UNSIGNED,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (id_publishers) REFERENCES publishers (id)
		ON UPDATE CASCADE
		ON DELETE SET NULL
) COMMENT = 'Таблица книг';

CREATE TABLE books_on_stock (
	id SERIAL PRIMARY KEY,
	id_books BIGINT UNSIGNED,
	received_from BIGINT UNSIGNED,  
	registred_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	reserved_by BIGINT UNSIGNED DEFAULT NULL,
	received_by BIGINT UNSIGNED DEFAULT NULL,
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE SET NULL,
	FOREIGN KEY (received_from) REFERENCES users (id)
		ON UPDATE CASCADE
		ON DELETE SET NULL,
	FOREIGN KEY (reserved_by) REFERENCES users (id)
		ON UPDATE CASCADE
		ON DELETE SET NULL,
	FOREIGN KEY (received_by) REFERENCES users (id)
		ON UPDATE CASCADE
		ON DELETE SET NULL
) COMMENT = 'Таблица книг в наличии';

CREATE TABLE users_wishlists (
	id_users BIGINT UNSIGNED,
	id_books BIGINT UNSIGNED,
	wish_count SMALLINT UNSIGNED DEFAULT 1,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (id_users, id_books),
	FOREIGN KEY (id_users) REFERENCES users (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE,
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) COMMENT = 'Таблица желаемых книг пользователей';

CREATE TABLE books_authors (
	id_books BIGINT UNSIGNED,
	id_authors BIGINT UNSIGNED,
	PRIMARY KEY (id_books, id_authors),
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE,
	FOREIGN KEY (id_authors) REFERENCES authors (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) COMMENT = 'Таблица связей книг и авторов';

CREATE TABLE books_languages (
	id_books BIGINT UNSIGNED,
	id_languages SMALLINT UNSIGNED,
	PRIMARY KEY (id_books, id_languages),
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE,
	FOREIGN KEY (id_languages) REFERENCES languages (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) COMMENT = 'Таблица связей книг и языков';

CREATE TABLE books_categories (
	id_books BIGINT UNSIGNED,
	id_categories SMALLINT UNSIGNED,
	PRIMARY KEY (id_books, id_categories),
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE,
	FOREIGN KEY (id_categories) REFERENCES categories (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) COMMENT = 'Таблица связей книг и каталогов';

CREATE TABLE books_photos (
	id SERIAL PRIMARY KEY,
	photo VARCHAR(255),
	id_books BIGINT UNSIGNED,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) COMMENT = 'Таблица фотографий книг';

CREATE TABLE users_comments (
	id SERIAL PRIMARY KEY,
	user_comment TEXT,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	id_users BIGINT UNSIGNED,
	id_books BIGINT UNSIGNED,
	FOREIGN KEY (id_users) REFERENCES users (id)
		ON UPDATE CASCADE
		ON DELETE SET NULL,
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) COMMENT = 'Таблица комментариев к книгам';

CREATE TABLE books_rating (
	id_users BIGINT UNSIGNED,
	id_books BIGINT UNSIGNED,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	rating ENUM ('Awfull', 'Bad', 'Normal', 'Good', 'Perfect') DEFAULT 'Normal',
	PRIMARY KEY (id_users, id_books),
	FOREIGN KEY (id_users) REFERENCES users (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE,
	FOREIGN KEY (id_books) REFERENCES books (id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) COMMENT = 'Таблица рейтинга книг';
