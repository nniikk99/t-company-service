-- Проверяем пользователей в базе данных
-- Проблема: пользователь с ID 00000000-0000-0000-0000-000000000002 не найден

-- 1. Проверяем всех пользователей в user_profiles
SELECT id, first_name, last_name, phone, role, company_inn
FROM user_profiles 
ORDER BY created_at DESC;

-- 2. Проверяем конкретно пользователя с ID 00000000-0000-0000-0000-000000000002
SELECT id, first_name, last_name, phone, role, company_inn
FROM user_profiles 
WHERE id = '00000000-0000-0000-0000-000000000002';

-- 3. Проверяем пользователя с ID 00000000-0000-0000-0000-000000000001 (админ)
SELECT id, first_name, last_name, phone, role, company_inn
FROM user_profiles 
WHERE id = '00000000-0000-0000-0000-000000000001';

-- 4. Создаем недостающего пользователя Мария Петрова
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
    '00000000-0000-0000-0000-000000000002',
    'Мария',
    'Петрова',
    '+7 (981) 746-73-96',
    'maria.petrova@testcompany.ru',
    'companyResponsible',
    'Ответственное лицо',
    '00000000-0000-0000-0000-000000000001',
    '0000000001',
    true,
    'ed529eae81c9b19580f0c948d5cb8c3a3b476c5a4b53e74d7118e8814cf16201', -- пароль: admin123
    true,
    NOW(),
    NOW()
);

-- 5. Проверяем, что пользователь создан
SELECT id, first_name, last_name, phone, role, company_inn
FROM user_profiles 
WHERE id = '00000000-0000-0000-0000-000000000002';
