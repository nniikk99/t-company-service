-- ПРОВЕРКА СОСТОЯНИЯ НАЗНАЧЕНИЯ ПЛОЩАДОК

-- 1. Проверяем всех пользователей с ролями siteManager и operatorPM
SELECT 
    id,
    first_name, 
    last_name, 
    role, 
    company_id, 
    company_inn,
    assigned_site_ids,
    updated_at
FROM user_profiles 
WHERE role IN ('siteManager', 'operatorPM')
ORDER BY first_name;

-- 2. Проверяем все площадки
SELECT 
    id,
    name,
    company_id,
    company_inn,
    created_at
FROM sites 
ORDER BY name;

-- 3. Проверяем RLS политики для user_profiles
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'user_profiles' AND cmd = 'UPDATE';

-- 4. Проверяем функции RLS
SELECT 
    proname as function_name,
    prosrc as function_body
FROM pg_proc 
WHERE proname IN ('disable_rls_for_update', 'enable_rls_after_update');
