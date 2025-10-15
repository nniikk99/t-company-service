-- ПРОВЕРКА И ИСПРАВЛЕНИЕ СОСТОЯНИЯ НАЗНАЧЕНИЯ ПЛОЩАДОК

-- 1. Проверяем текущее состояние пользователей
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

-- 5. Если функции не существуют, создаем их
CREATE OR REPLACE FUNCTION disable_rls_for_update()
RETURNS void AS $$
BEGIN
  ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION enable_rls_after_update()
RETURNS void AS $$
BEGIN
  ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Удаляем старые политики и создаем новые
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON user_profiles;
DROP POLICY IF EXISTS "Company responsible can update employees" ON user_profiles;

-- Создаем новые правильные политики
CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can update any profile" ON user_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() 
            AND up.role IN ('superAdmin', 'administrator')
        )
    );

CREATE POLICY "Company responsible can update employees" ON user_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() 
            AND up.role = 'companyResponsible'
            AND up.company_id = user_profiles.company_id
        )
    );

-- 7. Проверяем, что assigned_site_ids имеет правильный тип данных
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND column_name = 'assigned_site_ids';

-- 8. Если нужно, исправляем тип данных assigned_site_ids
-- ALTER TABLE user_profiles ALTER COLUMN assigned_site_ids TYPE text[] USING assigned_site_ids::text[];

-- 9. Тестируем обновление assigned_site_ids напрямую
-- UPDATE user_profiles 
-- SET assigned_site_ids = ARRAY['test-site-id'] 
-- WHERE id = 'c1f70b19-b090-40f2-8be6-23a29785dc33';

-- 10. Проверяем результат тестового обновления
-- SELECT id, first_name, last_name, assigned_site_ids 
-- FROM user_profiles 
-- WHERE id = 'c1f70b19-b090-40f2-8be6-23a29785dc33';
