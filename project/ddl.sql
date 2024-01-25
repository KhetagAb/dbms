CREATE TABLE Users
(
    user_id           serial PRIMARY KEY,
    user_name         varchar(40)             NOT NULL,
    password_hash     varchar(100),
    phone_number      char(13)                NOT NULL UNIQUE,
    registration_date timestamp DEFAULT NOW() NOT NULL,
    CONSTRAINT chk_phone_number CHECK (phone_number NOT LIKE '%[^0-9]%')
);

CREATE TABLE Channels
(
    channel_id        serial PRIMARY KEY,
    channel_name      varchar(30)             NOT NULL,
    owner_id          int                     NOT NULL,
    registration_date timestamp DEFAULT NOW() NOT NULL
);

CREATE TABLE ChannelManagers
(
    channel_id int NOT NULL REFERENCES Channels (channel_id),
    user_id    int NOT NULL REFERENCES Users (user_id),
    CONSTRAINT channel_managers_pk PRIMARY KEY (user_id, channel_id)
);

-- Циклическая зависимость между Positives и PositiveTypes -> отдельное определение ограничений
ALTER TABLE Channels
    ADD CONSTRAINT channels_managers_fk FOREIGN KEY (channel_id, owner_id) REFERENCES ChannelManagers (channel_id, user_id) DEFERRABLE INITIALLY IMMEDIATE;

CREATE TABLE Subscriptions
(
    channel_id int                     NOT NULL REFERENCES Channels (channel_id),
    user_id    int                     NOT NULL REFERENCES Users (user_id),
    date       timestamp DEFAULT NOW() NOT NULL,
    CONSTRAINT channel_user_pk PRIMARY KEY (channel_id, user_id)
);

CREATE TABLE Categories
(
    category_id   serial PRIMARY KEY,
    category_name varchar(15) NOT NULL
);

CREATE TABLE ChannelCategories
(
    category_id int NOT NULL REFERENCES Categories (category_id) ON DELETE CASCADE,
    channel_id  int NOT NULL REFERENCES Channels (channel_id) ON DELETE CASCADE,
    CONSTRAINT channel_categories_pk PRIMARY KEY (category_id, channel_id)
);

CREATE TABLE Publications
(
    publication_id   serial PRIMARY KEY,
    title            varchar(30)             NOT NULL CHECK (title <> ''),
    publication_date timestamp DEFAULT NOW() NOT NULL,
    channel_id       int                     NOT NULL REFERENCES Channels (channel_id),
    description      varchar(1000),
    hosting_url      varchar(90),
    content          text
);

CREATE TABLE PublicationCategories
(
    category_id    int NOT NULL REFERENCES Categories (category_id) ON DELETE CASCADE,
    publication_id int NOT NULL REFERENCES Publications (publication_id) ON DELETE CASCADE,
    CONSTRAINT publications_categories_pk PRIMARY KEY (category_id, publication_id)
);

CREATE TABLE Comments
(
    comment_id     serial PRIMARY KEY,
    content        text                    NOT NULL CHECK (content <> ''),
    user_id        int                     NOT NULL REFERENCES Users (user_id),
    publication_id int                     NOT NULL REFERENCES Publications (publication_id),
    date           timestamp DEFAULT NOW() NOT NULL
);

CREATE TABLE Bookmarks
(
    publication_id int                     NOT NULL REFERENCES Publications (publication_id),
    user_id        int                     NOT NULL REFERENCES Users (user_id),
    date           timestamp DEFAULT NOW() NOT NULL,
    seen           boolean   DEFAULT FALSE NOT NULL
);

CREATE TYPE PositiveType AS enum ('view', 'like', 'dislike');

CREATE TABLE Positives
(
    positive_id    serial PRIMARY KEY,
    positive_type  positivetype            NOT NULL,
    user_id        int                     NOT NULL REFERENCES Users (user_id) ON DELETE CASCADE,
    publication_id int                     NOT NULL REFERENCES Publications (publication_id),
    date           timestamp DEFAULT NOW() NOT NULL,
    CONSTRAINT positives_user_publication_uq UNIQUE (user_id, publication_id)
);

CREATE TABLE PositiveTypes
(
    positive_id   int          NOT NULL REFERENCES Positives (positive_id),
    positive_type positivetype NOT NULL,
    CONSTRAINT positive_types_pk PRIMARY KEY (positive_id, positive_type)
);

-- Циклическая зависимость между Positives и PositiveTypes -> отдельное определение ограничений
ALTER TABLE Positives
    ADD CONSTRAINT positive_types_fk FOREIGN KEY (positive_id, positive_type)
        REFERENCES PositiveTypes (positive_id, positive_type) DEFERRABLE INITIALLY IMMEDIATE;;

CREATE TABLE ShowPublicationEvents
(
    positive_id    int                     NOT NULL REFERENCES Positives (positive_id),
    user_id        int                     NOT NULL REFERENCES Users (user_id),
    publication_id int                     NOT NULL REFERENCES Publications (publication_id),
    date           timestamp DEFAULT NOW() NOT NULL,
    CONSTRAINT show_publcication_events_pk PRIMARY KEY (positive_id, user_id, publication_id)
);

-- Помним что PostreSQL автоматически создает индексы на первичные ключи и ограничения уникальности

-- Для AuthUser: Ускорение поиска пользователя по номеру телефона и паролю при аутентификации
CREATE INDEX idx_channels_channel_name ON Channels USING btree (channel_name);

-- Для GetChannelsIds: Быстрый поиск идентификаторов каналов по их названию
CREATE INDEX idx_auth_user_phone_password ON Users USING hash (password_hash);

-- Из документации PostgreSQL
-- A multicolumn B-tree index can be used with query conditions that involve any subset of the index's columns,
-- but the index is most efficient when there are constraints on the leading (leftmost) columns.
-- Помним это для таблиц с составным первичным ключи

-- Для GetChannelManagers: Улучшение производительности при получении информации о менеджерах канала по его идентификатору
CREATE INDEX idx_channels_channel_id ON ChannelManagers USING btree (channel_id);

-- Для GetChannelCategories: Ускорение поиска категорий канала по его идентификатору
CREATE INDEX idx_channel_categories_channel_id ON ChannelCategories USING btree (channel_id);

-- Для GetAllChannelPublicationsCategories: аналогично GetChannelCategories
CREATE INDEX idx_publications_categories_publication_id ON PublicationCategories USING btree (publication_id);

-- Для GetUserSubscriptions: Поиска подписок пользователя по его идентификатору
CREATE INDEX idx_subscriptions_user_id ON Subscriptions USING btree (user_id);

-- Для GetUnsubscribedUsersComments: Получение комментариев от пользователей
CREATE INDEX idx_comments_publication_id ON Comments USING btree (publication_id);

-- Для GetMostPositivityUsers: Получение топ-3 пользователей с наибольшим количеством позитивных отзывов
CREATE INDEX idx_positives_publication_id ON Positives USING btree (publication_id);
