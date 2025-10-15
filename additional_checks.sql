-- Дополнительные проверки для недостающих таблиц и полей

-- 1. Проверяем таблицу sites
SELECT 'sites' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sites') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 2. Проверяем таблицу user_companies
SELECT 'user_companies' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_companies') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 3. Проверяем таблицу company_requests
SELECT 'company_requests' as table_name, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'company_requests') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 4. Проверяем поле sites.company_inn
SELECT 'sites.company_inn' as field_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'sites' AND column_name = 'company_inn') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 5. Проверяем поле equipment.company_inn
SELECT 'equipment.company_inn' as field_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'equipment' AND column_name = 'company_inn') 
            THEN 'EXISTS' ELSE 'MISSING' END as status;

-- 6. Проверяем количество записей в недостающих таблицах
SELECT COUNT(*) as sites_count FROM sites;
SELECT COUNT(*) as user_companies_count FROM user_companies;
SELECT COUNT(*) as company_requests_count FROM company_requests;
