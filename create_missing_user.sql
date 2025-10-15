-- Создаем пользователя с ID из ошибки
-- ID: bcc40db9-f3f6-46d2-a553-a1d8afc5fae1

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
    'ed529eae81c9b19580f0c948d5cb8c3a3b476c5a4b53e74d7118e8814cf16201', -- пароль: admin123
    true,
    NOW(),
    NOW()
);

-- Проверяем, что пользователь создан
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
