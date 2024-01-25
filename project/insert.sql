-- Во всех тестовых данных для простоты сознательно оставлена сильная связность с конкретными идентификаторами
-- В тестовых данных считаем что кол-во публикаций/комментов/категорий и т.д. константами --> заполняем другие таблицы исходя из этого предположения
-- Только для таблицы Users знание о структуре идентификаторов сокрыто и для явного указания идентификатора используется AuthUser

INSERT INTO Categories
VALUES (1, 'Cinema'),
       (2, 'Sport'),
       (3, 'Games'),
       (4, 'Politics'),
       (5, 'Edicational');

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Заведем пару пользователей-авторов каналов и 100 пользователей-пустышек
CREATE OR REPLACE PROCEDURE RegisterUser(
    IN p_user_name varchar(40),
    IN p_password varchar(32),
    IN p_phone_number char(13),
    IN p_registration_date timestamp
)
    LANGUAGE plpgsql AS
$$
BEGIN
    INSERT INTO Users (user_name, password_hash, phone_number, registration_date)
    VALUES (p_user_name, crypt(p_password, gen_salt('bf')), p_phone_number, p_registration_date);
END;
$$;

-- Для сокрытия способа присвоения идентификатора в наполнении будем использовать функцию для аутентификации и регистрации пользователя
CREATE OR REPLACE FUNCTION AuthUser(
    f_phone_number char(13),
    f_password varchar(32)) RETURNS int
AS
$$
BEGIN
    RETURN (SELECT user_id
            FROM users
            WHERE phone_number = f_phone_number
              AND password_hash = crypt(f_password, password_hash));
END;
$$ LANGUAGE plpgsql;


CALL RegisterUser('Konstantin Bats', 'qwerty123', '88005553535', NOW()::timestamp);
CALL RegisterUser('Khet Dzestelov', 'qwerty123', '88005553536', NOW()::timestamp);
CALL RegisterUser('Georgiy Korneev', 'qwerty124', '88005553537', NOW()::timestamp);
CALL RegisterUser('Andrew Stankevich', 'qwerty125', '88005553538', NOW()::timestamp);

SELECT AuthUser('88005553536', 'qwerty12');
SELECT AuthUser('88005553536', 'qwerty123');

DO
$$
    DECLARE
        user_name varchar;
    BEGIN
        FOR user_name IN (SELECT first_name || ' ' || last_name AS full_name
                          FROM UNNEST(ARRAY ['Alice', 'Bob', 'Charlie', 'David', 'Eva', 'Frank', 'Grace', 'Henry', 'Ivy', 'Jack']) AS first_name,
                               UNNEST(ARRAY ['Smith', 'Johnson', 'Brown', 'Lee', 'Wang', 'Wilson', 'Garcia', 'Taylor', 'Clark', 'Lee']) AS last_name
                          ORDER BY RANDOM())
            LOOP
                CALL RegisterUser(
                        user_name,
                        'qweerty' || RANDOM(),
                        '7' || LPAD(FLOOR(RANDOM() * 1000000000)::text, 10, '0'),
                        NOW()::timestamp
                    );
            END LOOP;
    END
$$;

-- Настроим пару каналов

-- Так как у нас многие ко многим с одним обязательным, требуется транзакционно добавлять каналы и менеджеров к ним
BEGIN;
SET CONSTRAINTS ALL DEFERRED;

INSERT INTO Channels(channel_id, channel_name, owner_id)
VALUES (1, 'CT Lectures', AuthUser('88005553535', 'qwerty123')),
       (2, 'Khetag Personal', AuthUser('88005553536', 'qwerty123')),
       (3, 'kgeorgiy''s courses', AuthUser('88005553537', 'qwerty124')),
       (4, 'Andrew Stankevich', AuthUser('88005553538', 'qwerty125'));

INSERT INTO ChannelManagers(channel_id, user_id)
VALUES (1, AuthUser('88005553535', 'qwerty123')),
       (2, AuthUser('88005553536', 'qwerty123')),
       (3, AuthUser('88005553537', 'qwerty124')),
       (4, AuthUser('88005553538', 'qwerty125'));

COMMIT;

INSERT INTO ChannelManagers(channel_id, user_id)
VALUES (1, AuthUser('88005553536', 'qwerty123')),
       (1, AuthUser('88005553537', 'qwerty124')),
       (1, AuthUser('88005553538', 'qwerty125')),
       (3, AuthUser('88005553535', 'qwerty123'));

INSERT INTO ChannelCategories(category_id, channel_id)
VALUES (5, 1),
       (5, 3),
       (5, 4),
       (4, 2),
       (3, 2);

-- Подписки на каналы
INSERT INTO Subscriptions(channel_id, user_id)
SELECT 1, user_id
FROM Users
ORDER BY RANDOM()
LIMIT 90;

INSERT INTO Subscriptions(channel_id, user_id)
SELECT 2, user_id
FROM Users
ORDER BY RANDOM()
LIMIT 5;

INSERT INTO Subscriptions(channel_id, user_id)
SELECT 3, user_id
FROM Users
ORDER BY RANDOM()
LIMIT 40;

INSERT INTO Subscriptions(channel_id, user_id)
SELECT 4, user_id
FROM Users
ORDER BY RANDOM()
LIMIT 30;

-- Публикации, 50% видео, 50% статьи
INSERT INTO Publications (publication_id, title, publication_date, channel_id, description, hosting_url, content)
SELECT i,
       'Publication ' || i,
       NOW() - (i || ' days')::interval,
       (i % 4) + 1,
       CASE WHEN i % 2 = 0 THEN 'Some description' END,
       CASE WHEN i % 2 = 0 THEN 'https://video.infra.content.platform.ru/default' END,
       CASE WHEN i % 2 = 1 THEN 'Some content' END
FROM GENERATE_SERIES(1, 50) AS i;

-- Категории к публикациям
INSERT INTO PublicationCategories(category_id, publication_id)
SELECT 1, publication_id
FROM Publications
WHERE channel_id = 2
ORDER BY RANDOM()
LIMIT 3;

INSERT INTO PublicationCategories(category_id, publication_id)
SELECT 2, publication_id
FROM Publications
WHERE channel_id = 2
ORDER BY RANDOM()
LIMIT 3;

INSERT INTO PublicationCategories(category_id, publication_id)
SELECT 4, publication_id
FROM Publications
WHERE channel_id = 2
ORDER BY RANDOM()
LIMIT 3;

INSERT INTO PublicationCategories(category_id, publication_id)
SELECT 2, publication_id
FROM Publications
WHERE channel_id = 3
ORDER BY RANDOM()
LIMIT 3;

INSERT INTO PublicationCategories(category_id, publication_id)
SELECT 5, publication_id
FROM Publications
ORDER BY RANDOM()
LIMIT 40;

-- Комментарии к публикациям
INSERT INTO Comments (user_id, publication_id, content)
SELECT (i + (RANDOM() * 10)::int) % 100 + 1,
       (i % 50) + 1,
       'bla bla bla cool content! i like you №' || i
FROM GENERATE_SERIES(1, 400) AS i;

-- Закладки к публикациям
INSERT INTO Bookmarks(publication_id, user_id)
SELECT publication_id, user_id
FROM Publications,
     Users
ORDER BY RANDOM()
LIMIT 500;

CREATE OR REPLACE PROCEDURE AddPositiveToPublication(
    p_user_id int,
    p_publication_id int,
    p_positive_type PositiveType
)
AS
$$
DECLARE
    inserted_positive_id int;
BEGIN
    SET CONSTRAINTS ALL DEFERRED;

    BEGIN
        INSERT INTO Positives (positive_type, user_id, publication_id)
        VALUES (p_positive_type, p_user_id, p_publication_id)
        RETURNING positive_id INTO inserted_positive_id;

    EXCEPTION
        WHEN unique_violation THEN
            inserted_positive_id := (SELECT positive_id
                                     FROM Positives
                                     WHERE user_id = p_user_id
                                       AND publication_id = p_publication_id
                                     LIMIT 1);
    END;

    INSERT INTO PositiveTypes (positive_id, positive_type)
    VALUES (inserted_positive_id, p_positive_type);
END;
$$ LANGUAGE plpgsql;

DO
$$
    DECLARE
        i_user_id        int;
        i_publication_id int;
    BEGIN
        FOR i IN 1..100
            LOOP
                BEGIN
                    SELECT user_id FROM Users ORDER BY RANDOM() LIMIT 1 INTO i_user_id;
                    SELECT publication_id FROM Publications ORDER BY RANDOM() LIMIT 1 INTO i_publication_id;
                    CALL AddPositiveToPublication(i_user_id, i_publication_id, 'like');

                -- В процедуре нельзя просто выбрать часть из декартового произведения, проходится идти окольными путями :(
                EXCEPTION
                    WHEN OTHERS THEN
                        CONTINUE;
                END;
            END LOOP;

        FOR i IN 1..50
            LOOP
                BEGIN
                    SELECT user_id FROM Users ORDER BY RANDOM() LIMIT 1 INTO i_user_id;
                    SELECT publication_id FROM Publications ORDER BY RANDOM() LIMIT 1 INTO i_publication_id;
                    CALL AddPositiveToPublication(i_user_id, i_publication_id, 'dislike');
                EXCEPTION
                    WHEN OTHERS THEN
                        CONTINUE;
                END;
            END LOOP;

        FOR i IN 1..1000
            LOOP
                BEGIN
                    SELECT user_id FROM Users ORDER BY RANDOM() LIMIT 1 INTO i_user_id;
                    SELECT publication_id FROM Publications ORDER BY RANDOM() LIMIT 1 INTO i_publication_id;
                    CALL AddPositiveToPublication(i_user_id, i_publication_id, 'view');
                EXCEPTION
                    WHEN OTHERS THEN
                        CONTINUE;
                END;
            END LOOP;
    END
$$