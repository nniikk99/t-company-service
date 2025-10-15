-- Исправляем данные инженера в базе данных
-- Шаг 1: Убедимся, что компания 'Test company' существует
INSERT INTO companies (id, name, company_inn, address, email, phone, created_at, updated_at)
VALUES (
    'a1b2c3d4-e5f6-7890-1234-567890abcdef',
    'Test company',
    '0000000001',
    'г. Москва, ул. Тестовая, д. 1',
    'info@testcompany.com',
    '+7 (495) 123-45-67',
    NOW(),
    NOW()
)
ON CONFLICT (company_inn) DO UPDATE SET
    name = EXCLUDED.name,
    address = EXCLUDED.address,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    updated_at = EXCLUDED.updated_at;

-- Шаг 2: Удаляем старую запись инженера, если она есть
DELETE FROM user_profiles WHERE phone = '+7 (999) 123-45-67';

-- Шаг 3: Создаем нового инженера с правильными данными
INSERT INTO user_profiles (
    id, first_name, last_name, email, phone, role, position,
    company_id, company_name, company_inn, company_address, company_phone, company_email,
    can_manage_requests_independently, telegram_id, telegram_user_id, telegram_username,
    consent_to_personal_data, is_active, created_at, updated_at, password_hash
) VALUES (
    '83c74ef6-497f-4640-957a-463cda010065',
    'Иван', 'Инженеров', 'engineer@test.com', '+7 (999) 123-45-67', 'engineer', 'Инженер по обслуживанию',
    (SELECT id FROM companies WHERE company_inn = '0000000001' LIMIT 1),
    'Test company', '0000000001', 'г. Москва, ул. Тестовая, д. 1', '+7 (495) 123-45-67', 'info@testcompany.com',
    false, 'engineer_telegram_id', 123456789, 'engineer_test',
    true, true, NOW(), NOW(), '123456'
);

-- Шаг 4: Удаляем старую запись в user_companies, если есть
DELETE FROM user_companies WHERE user_id = '83c74ef6-497f-4640-957a-463cda010065';

-- Шаг 5: Создаем запись в user_companies для инженера
INSERT INTO user_companies (user_id, company_id, company_inn, company_name, role, status, created_at, updated_at)
SELECT
    up.id,
    c.id,
    up.company_inn,
    up.company_name,
    up.role,
    'approved',
    NOW(),
    NOW()
FROM user_profiles up
JOIN companies c ON up.company_inn = c.company_inn
WHERE up.id = '83c74ef6-497f-4640-957a-463cda010065';

-- Шаг 6: Проверяем результат
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.phone,
    up.role,
    up.password_hash,
    uc.company_name,
    uc.status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.phone = '+7 (999) 123-45-67';
