-- Проверка синхронизации базы данных с актуальным кодом
-- Этот скрипт проверяет все необходимые таблицы и поля

-- 1. Проверяем основные таблицы
SELECT 'companies' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'companies') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'user_profiles' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'sites' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sites') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'equipment' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'equipment') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 2. Проверяем новые таблицы для мульти-компаний
SELECT 'user_companies' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_companies') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'company_requests' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'company_requests') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'notifications' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 3. Проверяем поля company_inn в основных таблицах
SELECT 'user_profiles.company_inn' as field_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'user_profiles' AND column_name = 'company_inn') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'sites.company_inn' as field_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'sites' AND column_name = 'company_inn') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'equipment.company_inn' as field_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'equipment' AND column_name = 'company_inn') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

SELECT 'companies.company_inn' as field_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'companies' AND column_name = 'company_inn') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 4. Проверяем роли в user_profiles
SELECT DISTINCT role FROM user_profiles;

-- 5. Проверяем данные в новых таблицах
SELECT COUNT(*) as user_companies_count FROM user_companies;
SELECT COUNT(*) as company_requests_count FROM company_requests;
SELECT COUNT(*) as notifications_count FROM notifications;

-- 6. Проверяем RLS политики
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('user_companies', 'company_requests', 'notifications')
ORDER BY tablename, policyname;
