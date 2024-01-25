-- Аутентифицировать (получить внутренний id) пользователя по телефону и паролю
SELECT AuthUser('88005553536', 'qwerty12');
SELECT AuthUser('88005553536', 'qwerty123');

-- Узнать какие каналы имеют указанное название
CREATE OR REPLACE FUNCTION GetChannelsIds(f_channel_name varchar(30))
    RETURNS table
            (
                f_channel_id int
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT channel_id
                  FROM Channels
                  WHERE channel_name = f_channel_name);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetChannelsIds('kgeorgiy''s courses');
SELECT *
FROM GetChannelsIds('CT Lectures');

-- Узнать всех менеджеров канала
CREATE OR REPLACE FUNCTION GetChannelManagers(f_channel_id int)
    RETURNS table
            (
                channel_owners varchar(40),
                channel_owners_ids    int
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT user_name, user_id
                  FROM ChannelManagers
                           NATURAL JOIN Users
                  WHERE channel_id = f_channel_id);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetChannelManagers(3);
SELECT *
FROM GetChannelManagers(2);
SELECT *
FROM GetChannelManagers(1);

-- Узнать, какими каналами владеет пользователь
CREATE OR REPLACE FUNCTION GetManagedChannels(f_user_id int)
    RETURNS table
            (
                managed_channels varchar(30),
                managed_channel_ids   int
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT channel_name, channel_id
                  FROM ChannelManagers
                           NATURAL JOIN Channels
                  WHERE user_id = f_user_id);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetManagedChannels(3);
SELECT *
FROM GetManagedChannels(2);


-- Получить категории канала
CREATE OR REPLACE FUNCTION GetChannelCategories(f_channel_id int)
    RETURNS table
            (
                channel_categories varchar(15)
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT DISTINCT category_name
                  FROM ChannelCategories
                           NATURAL JOIN categories
                  WHERE channel_id = f_channel_id);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetChannelCategories(1);
SELECT *
FROM GetChannelCategories(2);

-- Получить категории всех публикаций канала
CREATE OR REPLACE FUNCTION GetAllChannelPublicationsCategories(f_channel_id int)
    RETURNS table
            (
                channel_categories varchar(15)
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT DISTINCT category_name
                  FROM Publications
                           NATURAL JOIN PublicationCategories
                           NATURAL JOIN Categories
                  WHERE channel_id = f_channel_id);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetAllChannelPublicationsCategories(2);
SELECT *
FROM GetAllChannelPublicationsCategories(4);

-- Получить подписки определенного пользователя
CREATE OR REPLACE FUNCTION GetUserSubscriptions(f_user_id int)
    RETURNS table
            (
                subscribed_channels varchar(30),
                subscribed_channel_ids   int
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT channel_name, channel_id
                  FROM Subscriptions
                           NATURAL JOIN Channels
                  WHERE user_id = f_user_id);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetUserSubscriptions(4);
SELECT *
FROM GetUserSubscriptions(57);

-- Получить количество подписчиков канала
CREATE OR REPLACE FUNCTION GetSubscriptionsCount(f_channel_id int)
    RETURNS int
AS
$$
BEGIN
    RETURN (SELECT COUNT(user_id)
            FROM Subscriptions
            WHERE channel_id = f_channel_id);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetSubscriptionsCount(2);
SELECT *
FROM GetSubscriptionsCount(3);


-- Получить все комментарии к публикации от пользователей, который не подписаны на канал
CREATE OR REPLACE FUNCTION GetUnsubscribedUsersComments(f_publication_id int)
    RETURNS table
            (
                comment_content text
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT Comments.content
                  FROM Publications
                           JOIN Comments USING (publication_id)
                  WHERE publication_id = f_publication_id
                    AND NOT EXISTS(
                          SELECT channel_id, user_id
                          FROM Subscriptions
                          WHERE Comments.user_id = Subscriptions.user_id
                            AND Publications.channel_id = Subscriptions.channel_id
                      ));
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetUnsubscribedUsersComments(16);
SELECT *
FROM GetUnsubscribedUsersComments(19);
SELECT *
FROM GetUnsubscribedUsersComments(44);

-- Получить всех пользователей, которые подписаны на канал, на публикацию которого оставили закладку
CREATE OR REPLACE FUNCTION GetSubscribedUsersWithBookmarkComments()
    RETURNS table
            (
                subscribed_bookmark_user_id int,
                subscribed_bookmark_user_name varchar(30)
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT DISTINCT Bookmarks.user_id, Users.user_name
                  FROM Bookmarks
                           NATURAL JOIN Publications
                           JOIN Subscriptions USING (channel_id, user_id)
                           JOIN Users USING (user_id));
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetSubscribedUsersWithBookmarkComments();

-- Получить топ-3 пользователей с наибольшим кол-вом позитивов для указанного канала
CREATE OR REPLACE FUNCTION GetMostPositivityUsers(f_channel_id int)
    RETURNS table
            (
                positivity_user int,
                total_positives bigint
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT Positives.user_id, COUNT(positive_id) AS total_positives
                        FROM Channels
                                 NATURAL JOIN Publications
                                 JOIN Positives USING (publication_id)
                        WHERE channel_id = f_channel_id
                        GROUP BY Positives.user_id
                        ORDER BY total_positives DESC
                        LIMIT 3);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM GetMostPositivityUsers(3)

