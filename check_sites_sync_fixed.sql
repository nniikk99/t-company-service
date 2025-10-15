-- ИСПРАВЛЕННЫЙ ЗАПРОС ДЛЯ ПРОВЕРКИ СИНХРОНИЗАЦИИ ПЛОЩАДОК
-- Сначала проверим правильную структуру таблицы sites

-- Шаг 1: Проверяем структуру таблицы sites
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'sites' 
ORDER BY ordinal_position;

-- Шаг 2: Проверяем все площадки в БД (используем правильные колонки)
SELECT 
    id,
    name,
    address,
    company_inn,
    phone,
    email,
    created_at,
    updated_at
FROM sites
ORDER BY created_at DESC;

-- Шаг 3: Проверяем площадку "123456" конкретно
SELECT 
    id,
    name,
    address,
    company_inn,
    phone,
    email,
    created_at,
    updated_at
FROM sites
WHERE name = '123456';

-- Шаг 4: Проверяем, какие пользователи связаны с компанией 0000000001
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

-- Шаг 5: Проверяем RLS политики для sites
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'sites';

-- Шаг 6: Тестируем доступ к площадкам для разных пользователей
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
