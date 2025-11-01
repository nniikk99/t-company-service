-- Проверка структуры таблиц после миграции

-- 1. Проверяем, что supplier_id добавлен в equipment
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'equipment' 
AND column_name = 'supplier_id';

-- 2. Проверяем, что supplier_id добавлен в service_requests
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'service_requests' 
AND column_name = 'supplier_id';

-- 3. Проверяем индексы
SELECT 
    indexname, 
    indexdef
FROM pg_indexes
WHERE tablename IN ('equipment', 'service_requests')
AND indexname LIKE '%supplier%';

-- 4. Проверяем активные RLS политики для service_requests
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'service_requests'
ORDER BY policyname;

-- 5. Проверяем активные RLS политики для equipment
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'equipment'
ORDER BY policyname;

