-- Удаление дубликата Ивана Сидорова
-- Оставляем только запись с ID: 00000000-0000-0000-0000-000000000003
-- Удаляем запись с ID: c1f70b19-b090-40f2-8be6-23a29785dc33

-- 1. Сначала проверим, что мы удаляем правильную запись
SELECT 
    id, 
    first_name, 
    last_name, 
    phone,
    email,
    role,
    assigned_site_ids,
    created_at,
    updated_at
FROM user_profiles 
WHERE id = 'c1f70b19-b090-40f2-8be6-23a29785dc33';

-- 2. Удаляем дубликат (запись с телефоном +7 (999) 222-22-22)
DELETE FROM user_profiles 
WHERE id = 'c1f70b19-b090-40f2-8be6-23a29785dc33';

-- 3. Проверяем результат - должен остаться только один Иван Сидоров
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

-- 4. Обновляем оставшуюся запись Ивана Сидорова (только Лемана Про)
UPDATE user_profiles
SET 
    assigned_site_ids = ARRAY['fe8767e3-7490-4f5a-ab73-9eec66c235af']::uuid[],
    updated_at = NOW()
WHERE id = '00000000-0000-0000-0000-000000000003';

-- 5. Финальная проверка
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

-- 6. Добавляем уникальные ограничения для предотвращения будущих дубликатов
ALTER TABLE user_profiles 
ADD CONSTRAINT unique_user_phone UNIQUE (phone);

ALTER TABLE user_profiles 
ADD CONSTRAINT unique_user_email UNIQUE (email);

-- 7. Проверяем, что ограничения добавлены
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'user_profiles'::regclass 
AND contype = 'u';

