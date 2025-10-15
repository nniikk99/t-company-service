-- ПРОВЕРЯЕМ СИНХРОНИЗАЦИЮ ПЛОЩАДОК С БД
-- Проверяем, видят ли другие пользователи площадку "123456"

-- Шаг 1: Проверяем все площадки в БД
SELECT 
    id,
    name,
    company_inn,
    created_at,
    updated_at
FROM sites
ORDER BY created_at DESC;

-- Шаг 2: Проверяем площадку "123456" конкретно
SELECT 
    id,
    name,
    address,
    company_inn,
    responsible_person,
    phone,
    email,
    created_at,
    updated_at
FROM sites
WHERE name = '123456';

-- Шаг 3: Проверяем, какие пользователи связаны с компанией 0000000001
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.role,
    up.company_inn,
    uc.company_name,
    uc.status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.company_inn = '0000000001' OR uc.company_inn = '0000000001'
ORDER BY up.created_at;

-- Шаг 4: Проверяем RLS политики для sites
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'sites';

-- Шаг 5: Тестируем доступ к площадкам для разных пользователей
-- (Этот запрос покажет, какие площадки видят пользователи с разными ролями)
SELECT 
    'Все площадки' as access_level,
    COUNT(*) as site_count
FROM sites
UNION ALL
SELECT 
    'Площадки компании 0000000001' as access_level,
    COUNT(*) as site_count
FROM sites
WHERE company_inn = '0000000001';
