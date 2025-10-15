-- Исправление дубликатов номера телефона 79817467395

-- 1. Показываем все записи с этим номером телефона
SELECT 
    id,
    first_name,
    last_name,
    phone,
    email,
    role,
    company_id,
    created_at,
    updated_at
FROM user_profiles 
WHERE phone = '79817467395'
ORDER BY created_at;

-- 2. Удаляем тестовые записи (оставляем только Михаила Юшко)
-- Удаляем "Имя Фамилия" и "имя фамилия" - это тестовые записи
DELETE FROM user_profiles 
WHERE id IN (
    'bcdcaf72-468a-40b8-b14f-672e313d4dfa',  -- Имя Фамилия
    'dfe3f05e-5366-4165-a007-15a6a9125cda'   -- имя фамилия
);

-- 3. Проверяем результат - должен остаться только Михаил Юшко
SELECT 
    id,
    first_name,
    last_name,
    phone,
    email,
    role,
    company_id,
    created_at,
    updated_at
FROM user_profiles 
WHERE phone = '79817467395'
ORDER BY created_at;

-- 4. Теперь удаляем дубликат Ивана Сидорова
DELETE FROM user_profiles 
WHERE id = 'c1f70b19-b090-40f2-8be6-23a29785dc33';

-- 5. Обновляем оставшегося Ивана Сидорова
UPDATE user_profiles
SET 
    assigned_site_ids = ARRAY['fe8767e3-7490-4f5a-ab73-9eec66c235af']::uuid[],
    updated_at = NOW()
WHERE id = '00000000-0000-0000-0000-000000000003';

-- 6. Проверяем, что дубликатов больше нет
SELECT 
    phone,
    COUNT(*) as count
FROM user_profiles 
GROUP BY phone
HAVING COUNT(*) > 1;

-- 7. Если дубликатов нет, добавляем уникальные ограничения
ALTER TABLE user_profiles 
ADD CONSTRAINT unique_user_phone UNIQUE (phone);

ALTER TABLE user_profiles 
ADD CONSTRAINT unique_user_email UNIQUE (email);

-- 8. Проверяем, что ограничения добавлены
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'user_profiles'::regclass 
AND contype = 'u';

-- 9. Финальная проверка - должен остаться только один Иван Сидоров
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

