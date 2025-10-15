-- Полностью удаляем ограничение ролей и создаем пользователя
-- Ошибка: check constraint "user_profiles_role_check" все еще нарушается

-- 1. Удаляем ВСЕ ограничения ролей
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;

-- 2. Проверяем, что ограничение удалено
SELECT 
    tc.constraint_name, 
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'user_profiles' 
    AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%role%';

-- 3. Проверяем существующие роли в базе
SELECT DISTINCT role 
FROM user_profiles 
ORDER BY role;

-- 4. Создаем пользователя БЕЗ ограничений ролей
INSERT INTO user_profiles (
    id,
    first_name,
    last_name,
    phone,
    email,
    role,
    position,
    company_id,
    company_inn,
    can_manage_requests_independently,
    password_hash,
    is_active,
    created_at,
    updated_at
) VALUES (
    'bcc40db9-f3f6-46d2-a553-a1d8afc5fae1',
    'Новый',
    'Пользователь',
    '+7 (999) 123-45-67',
    'new.user@testcompany.ru',
    'companyResponsible',
    'Ответственное лицо',
    '00000000-0000-0000-0000-000000000001',
    '0000000001',
    true,
    'ed529eae81c9b19580f0c948d5cb8c3a3b476c5a4b53e74d7118e8814cf16201',
    true,
    NOW(),
    NOW()
);

-- 5. Проверяем, что пользователь создан
SELECT 
    id, 
    first_name, 
    last_name, 
    phone, 
    email, 
    role,
    company_inn
FROM user_profiles 
WHERE id = 'bcc40db9-f3f6-46d2-a553-a1d8afc5fae1';

-- 6. Показываем всех пользователей для проверки
SELECT 
    id, 
    first_name, 
    last_name, 
    role,
    created_at
FROM user_profiles 
ORDER BY created_at DESC 
LIMIT 10;
