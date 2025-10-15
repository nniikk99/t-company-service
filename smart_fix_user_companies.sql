-- Умное исправление: создание записей в user_companies с проверкой существующих ответственных лиц

-- 1. Проверяем текущую ситуацию
SELECT 
    up.id as user_id,
    up.first_name,
    up.last_name,
    up.company_inn,
    up.company_name,
    up.role,
    COUNT(uc.id) as user_companies_count,
    -- Проверяем, есть ли уже ответственный для этой компании
    EXISTS(
        SELECT 1 FROM user_companies uc2 
        WHERE uc2.company_inn = up.company_inn 
        AND uc2.role = 'companyResponsible' 
        AND uc2.status = 'approved'
    ) as has_responsible_person
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.company_inn IS NOT NULL 
GROUP BY up.id, up.first_name, up.last_name, up.company_inn, up.company_name, up.role
ORDER BY up.created_at;

-- 2. Создаем записи в user_companies только для тех пользователей,
-- у которых нет записей в user_companies И их компания не имеет ответственного лица
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
    -- Логика ролей:
    -- Если компания не имеет ответственного лица, делаем пользователя ответственным
    -- Иначе даем роль в зависимости от текущей роли пользователя
    CASE 
        WHEN NOT EXISTS(
            SELECT 1 FROM user_companies uc2 
            WHERE uc2.company_inn = up.company_inn 
            AND uc2.role = 'companyResponsible' 
            AND uc2.status = 'approved'
        ) THEN 'companyResponsible'
        WHEN up.role = 'pendingApproval' THEN 'siteManager'
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
    STRING_AGG(uc.company_name || ' (' || uc.role || ')', ', ') as companies_with_roles
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.company_inn IS NOT NULL
GROUP BY up.id, up.first_name, up.last_name, up.company_inn
ORDER BY up.created_at;
