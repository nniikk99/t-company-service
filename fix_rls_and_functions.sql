-- ИСПРАВЛЕНИЕ RLS И СОЗДАНИЕ ФУНКЦИЙ ДЛЯ НАЗНАЧЕНИЯ ПЛОЩАДОК

-- 1. Создаем функции для управления RLS
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

-- 2. Удаляем старые политики
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON user_profiles;

-- 3. Создаем новые правильные политики
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

-- 4. Проверяем текущие политики
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- 5. Тестируем обновление напрямую
UPDATE user_profiles 
SET assigned_site_ids = ARRAY['fe8767e3-7490-4f5a-ab73-9eec66c235af']
WHERE id = '164fbf40-2862-49e5-a5c0-c22194a63bb2';

-- 6. Проверяем результат
SELECT 
    id, 
    first_name, 
    last_name, 
    role, 
    assigned_site_ids
FROM user_profiles 
WHERE id = '164fbf40-2862-49e5-a5c0-c22194a63bb2';
