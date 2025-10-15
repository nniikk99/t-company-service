-- Исправление: создание записей в user_companies для всех существующих пользователей
-- Это нужно для отображения их первых компаний в профиле

-- 1. Проверяем пользователей с company_inn но без записей в user_companies
SELECT 
    up.id as user_id,
    up.first_name,
    up.last_name,
    up.company_inn,
    up.company_name,
    up.role,
    COUNT(uc.id) as user_companies_count
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.company_inn IS NOT NULL 
GROUP BY up.id, up.first_name, up.last_name, up.company_inn, up.company_name, up.role
HAVING COUNT(uc.id) = 0
ORDER BY up.created_at;

-- 2. Создаем записи в user_companies для всех пользователей с company_inn
-- но без записей в user_companies
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
    -- Исправляем роль: если pendingApproval, то делаем companyResponsible для первой компании
    CASE 
        WHEN up.role = 'pendingApproval' THEN 'companyResponsible'
        ELSE up.role 
    END as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM user_profiles up
LEFT JOIN companies c ON up.company_inn = c.company_inn
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.company_inn IS NOT NULL 
  AND uc.id IS NULL  -- Только для тех, у кого нет записей в user_companies
  AND c.id IS NOT NULL;  -- Только если компания существует

-- 3. Проверяем результат
SELECT 
    up.id as user_id,
    up.first_name,
    up.last_name,
    up.company_inn,
    COUNT(uc.id) as user_companies_count,
    STRING_AGG(uc.company_name, ', ') as companies
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.company_inn IS NOT NULL
GROUP BY up.id, up.first_name, up.last_name, up.company_inn
ORDER BY up.created_at;
