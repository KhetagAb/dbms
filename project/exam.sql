ALTER TABLE PositiveTypes
    ADD COLUMN last_update_date timestamp NOT NULL DEFAULT now();

-- -- К сожалению все взаимодействия в рамках одного позитива мы считали по одному времени ;(
UPDATE PositiveTypes
    SET last_update_date = Positives.date
FROM Positives
    WHERE PositiveTypes.positive_id = Positives.positive_id;

ALTER TABLE Positives
    DROP COLUMN date;

-- Основное предложение: изначально не удалять лайк/дизлайк, а деактивировать его
-- Это целесообразно, ибо "отзывают" взаимодействия не очень часто, существенно не скажется на производительности

-- Далее о способе деактивации, думалось, что в случае деактивации взаимодействия можно установить время
-- В далекое будщее (скажем 3000 год, программисты того времени не дотянутся до меня за такое решение!)

-- Однако кажется, что введение столбца "is_cancelled" кажется решением получше,
    -- Проблемы: обновлять время возобновления взаимодействия с одновременным снятием флага is_cancelled

-- Считаю, что нам не может быть интересно, сколько лайков было за какой-то интервал в прошлом,
-- но нас могут интересовать все активные лайки на какому-то суффиксе времени,
-- тогда будет достаточно взять все взаимодействия за указанное время и проверить текущий флаг is_canceled.
ALTER TABLE PositiveTypes
    ADD COLUMN is_cancelled boolean NOT NULL DEFAULT false;

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

    BEGIN
        INSERT INTO PositiveTypes (positive_id, positive_type)
        VALUES (inserted_positive_id, p_positive_type);

        EXCEPTION
            WHEN OTHERS THEN
                UPDATE PositiveTypes
                SET last_update_date = now(),
                    is_cancelled = false
                WHERE positive_id = inserted_positive_id
                  AND positive_type = p_positive_type;
    END;
END;
$$ LANGUAGE plpgsql;

CALL AddPositiveToPublication(1, 4, 'like');

CREATE OR REPLACE PROCEDURE DeleteFeedbackPositive(
    IN p_positive_id int
)
AS
$$
BEGIN
    UPDATE PositiveTypes
    SET is_cancelled = true
    WHERE positive_id = p_positive_id
        AND (positive_type = 'like' OR positive_type = 'dislike');
END;
$$ LANGUAGE plpgsql;


CALL DeleteFeedbackPositive(233);

SELECT publication_id
FROM (SELECT COUNT(positive_type) AS like_count, publication_id
      FROM Positives
               NATURAL JOIN positivetypes
      WHERE is_cancelled = FALSE
        AND positive_type = 'like'
        AND last_update_date + INTERVAL '7d' >= now()
      GROUP BY publication_id
      ORDER BY like_count DESC
      LIMIT 10) as lcpi