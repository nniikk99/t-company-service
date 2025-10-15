-- ШАГ 2 (ФИНАЛЬНЫЙ): Создаем записи только для существующих пользователей
-- Используем только реальные user_id из таблицы user_profiles

-- 1. Пользователь test - добавляем его первую компанию "Test company" (ИНН 0000000001)
INSERT INTO user_companies (
    user_id,
    company_id,
    company_inn,
    company_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    '39fa2176-54c2-412f-9d01-52ef9cbf3c31' as user_id,
    c.id as company_id,
    '0000000001' as company_inn,
    'Test company' as company_name,
    'companyResponsible' as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM companies c 
WHERE c.company_inn = '0000000001';

-- 2. Админ Михаил Басалыгин - добавляем T-Company (ИНН 0000000000)
INSERT INTO user_companies (
    user_id,
    company_id,
    company_inn,
    company_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    '00000000-0000-0000-0000-000000000001' as user_id,
    c.id as company_id,
    '0000000000' as company_inn,
    'T-Company' as company_name,
    'superAdmin' as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM companies c 
WHERE c.company_inn = '0000000000';
