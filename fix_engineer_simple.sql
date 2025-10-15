-- Упрощенный скрипт для исправления данных инженера
-- Выполняйте по частям, если возникают ошибки

-- Шаг 1: Проверяем данные инженера
SELECT 
    id,
    first_name,
    last_name,
    phone,
    email,
    role,
    password_hash,
    is_active,
    company_inn,
    company_name
FROM user_profiles 
WHERE role = 'engineer';

-- Шаг 2: Обновляем пароль инженера (если он существует)
UPDATE user_profiles 
SET password_hash = '123456',
    is_active = true,
    phone = '+7 (999) 123-45-67',
    updated_at = NOW()
WHERE role = 'engineer';

-- Шаг 3: Если инженер не существует, создаем его
INSERT INTO user_profiles (
    id,
    first_name,
    last_name,
    email,
    phone,
    role,
    position,
    company_id,
    company_name,
    company_inn,
    company_address,
    company_phone,
    company_email,
    can_manage_requests_independently,
    telegram_id,
    telegram_user_id,
    telegram_username,
    consent_to_personal_data,
    is_active,
    password_hash,
    created_at,
    updated_at
) VALUES (
    '83c74ef6-497f-4640-957a-463cda010065',
    'Иван',
    'Инженеров',
    'engineer@test.com',
    '+7 (999) 123-45-67',
    'engineer',
    'Инженер по обслуживанию',
    (SELECT id FROM companies WHERE company_inn = '0000000001' LIMIT 1),
    'Test company',
    '0000000001',
    'г. Москва, ул. Тестовая, д. 1',
    '+7 (495) 123-45-67',
    'info@testcompany.com',
    false,
    'engineer_telegram_id',
    123456789,
    'engineer_test',
    true,
    true,
    '123456',
    NOW(),
    NOW()
) ON CONFLICT (id) DO UPDATE SET
    password_hash = '123456',
    is_active = true,
    phone = '+7 (999) 123-45-67',
    updated_at = NOW();

-- Шаг 4: Проверяем результат
SELECT 
    id,
    first_name,
    last_name,
    phone,
    password_hash,
    is_active,
    role
FROM user_profiles 
WHERE role = 'engineer';
