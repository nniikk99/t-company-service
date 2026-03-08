-- Восстанавливаем потерянные скрытые поля в таблице equipment из equipment_models
UPDATE equipment e
SET specifications = e.specifications || (
        SELECT jsonb_object_agg(key, value)
        FROM equipment_models em,
            jsonb_each(em.specifications)
        WHERE em.manufacturer = e.manufacturer
            AND em.model = e.model
            AND left(key, 1) = '_'
    )
WHERE EXISTS (
        SELECT 1
        FROM equipment_models em,
            jsonb_each(em.specifications)
        WHERE em.manufacturer = e.manufacturer
            AND em.model = e.model
            AND left(key, 1) = '_'
    );