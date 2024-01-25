-- READ COMMITTED
CREATE OR REPLACE PROCEDURE DeleteCategoryById(
    IN p_category_id int
)
AS
$$
BEGIN
    DELETE FROM Categories WHERE category_id = p_category_id;
END;
$$ LANGUAGE plpgsql;

CALL DeleteCategoryById(5);

-- READ COMMITTED
CREATE OR REPLACE PROCEDURE UpdatePublicationDescriptionById(
    IN p_publication_id int,
    IN p_new_description varchar
)
AS
$$
BEGIN
    UPDATE Publications
    SET description = p_new_description
    WHERE publication_id = p_publication_id
      AND description IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

CALL UpdatePublicationDescriptionById(2, 'New Cool description');

-- REPEATABLE READ
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

-- CALL AddPositiveToPublication(1, 1, 'view') -- если еще не добавлен в тестовые данные
