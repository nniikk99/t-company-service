-- Исправление всех дубликатов в user_profiles

-- 1. Сначала удаляем дубликат Ивана Сидорова (как мы планировали)
DELETE FROM user_profiles 
WHERE id = 'c1f70b19-b090-40f2-8be6-23a29785dc33';

-- 2. Обновляем оставшегося Ивана Сидорова
UPDATE user_profiles
SET 
    assigned_site_ids = ARRAY['fe8767e3-7490-4f5a-ab73-9eec66c235af']::uuid[],
    updated_at = NOW()
WHERE id = '00000000-0000-0000-0000-000000000003';

-- 3. Проверяем, есть ли другие дубликаты по номеру телефона
-- Если есть дубликаты администратора, оставляем только один
WITH admin_duplicates AS (
    SELECT id, created_at,
           ROW_NUMBER() OVER (ORDER BY created_at ASC) as rn
    FROM user_profiles 
    WHERE phone IN ('79817467395', '+7 (981) 746-73-95')
    AND role = 'superAdmin'
)
DELETE FROM user_profiles 
WHERE id IN (
    SELECT id FROM admin_duplicates WHERE rn > 1
);

-- 4. Проверяем результат - должны остаться только уникальные записи
SELECT 
    phone,
    COUNT(*) as count
FROM user_profiles 
GROUP BY phone
HAVING COUNT(*) > 1;

-- 5. Если дубликатов больше нет, добавляем уникальные ограничения
-- (Выполняйте только если запрос выше не вернул результатов)

-- Добавляем уникальные ограничения для предотвращения будущих дубликатов
ALTER TABLE user_profiles 
ADD CONSTRAINT unique_user_phone UNIQUE (phone);

ALTER TABLE user_profiles 
ADD CONSTRAINT unique_user_email UNIQUE (email);

-- 6. Проверяем, что ограничения добавлены
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'user_profiles'::regclass 
AND contype = 'u';

-- 7. Финальная проверка - должен остаться только один Иван Сидоров
SELECT 
    id, 
    first_name, 
    last_name, 
    phone,
    email,
    role,
    assigned_site_ids,
    company_id,
    company_inn
FROM user_profiles 
WHERE first_name = 'Иван' AND last_name = 'Сидоров';

