-- Проверяем и исправляем данные инженера
-- Шаг 1: Проверяем текущее состояние
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
WHERE role = 'engineer' OR phone = '+7 (999) 123-45-67';

-- Шаг 2: Обновляем данные инженера
UPDATE user_profiles 
SET 
    first_name = 'Иван',
    last_name = 'Инженеров',
    email = 'engineer@test.com',
    phone = '+7 (999) 123-45-67',
    role = 'engineer',
    position = 'Инженер по обслуживанию',
    company_id = (SELECT id FROM companies WHERE company_inn = '0000000001' LIMIT 1),
    company_name = 'Test company',
    company_inn = '0000000001',
    company_address = 'г. Москва, ул. Тестовая, д. 1',
    company_phone = '+7 (495) 123-45-67',
    company_email = 'info@testcompany.com',
    can_manage_requests_independently = false,
    telegram_id = 'engineer_telegram_id',
    telegram_user_id = 123456789,
    telegram_username = 'engineer_test',
    consent_to_personal_data = true,
    is_active = true,
    password_hash = '123456',
    updated_at = NOW()
WHERE id = '83c74ef6-497f-4640-957a-463cda010065';

-- Шаг 3: Проверяем результат
SELECT 
    id,
    first_name,
    last_name,
    phone,
    password_hash,
    is_active,
    role,
    company_inn
FROM user_profiles 
WHERE role = 'engineer';
