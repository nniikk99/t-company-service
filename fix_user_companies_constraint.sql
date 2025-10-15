-- Исправляем ограничение user_companies_role_check для поддержки роли engineer

-- Шаг 1: Удаляем старое ограничение
ALTER TABLE user_companies DROP CONSTRAINT IF EXISTS user_companies_role_check;

-- Шаг 2: Создаем новое ограничение с поддержкой роли engineer
ALTER TABLE user_companies ADD CONSTRAINT user_companies_role_check 
CHECK (role IN (
    'pendingApproval',
    'operatorPM', 
    'engineer',
    'siteManager',
    'companyResponsible',
    'administrator',
    'superAdmin',
    'admin',
    'clientManager',
    'clientResponsible',
    'contactPerson'
));

-- Шаг 3: Теперь создаем записи в user_companies
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
    up.id as user_id,
    c.id as company_id,
    up.company_inn,
    COALESCE(up.company_name, c.name) as company_name,
    'companyResponsible' as role, -- Первая компания всегда companyResponsible
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM user_profiles up
LEFT JOIN companies c ON up.company_inn = c.company_inn
WHERE up.id = '39fa2176-54c2-412f-9d01-52ef9cbf3c31' -- ID пользователя Test
  AND up.company_inn = '1234567890' -- ИНН его компании
ON CONFLICT (user_id, company_id) DO NOTHING;

-- Шаг 4: Создаем запись для инженера
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
    up.id as user_id,
    c.id as company_id,
    up.company_inn,
    COALESCE(up.company_name, c.name) as company_name,
    'engineer' as role, -- Инженер остается инженером
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM user_profiles up
LEFT JOIN companies c ON up.company_inn = c.company_inn
WHERE up.id = '83c74ef6-497f-4640-957a-463cda010065' -- ID инженера
  AND up.company_inn = '0000000001' -- ИНН его компании
ON CONFLICT (user_id, company_id) DO NOTHING;

-- Шаг 5: Проверяем результат
SELECT 
    up.id as user_id,
    up.first_name,
    up.last_name,
    up.phone,
    up.role as profile_role,
    up.company_inn as profile_company_inn,
    uc.company_inn as user_company_inn,
    uc.company_name as user_company_name,
    uc.role as user_company_role,
    uc.status as user_company_status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.id IN ('39fa2176-54c2-412f-9d01-52ef9cbf3c31', '83c74ef6-497f-4640-957a-463cda010065')
ORDER BY up.first_name;
