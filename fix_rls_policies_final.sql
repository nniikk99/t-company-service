-- ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ RLS ПОЛИТИК ДЛЯ user_profiles

-- 1. Удаляем все существующие политики
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can read their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can read any profile" ON user_profiles;

-- 2. Временно отключаем RLS для тестирования
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- 3. Проверяем текущее состояние пользователей
SELECT 
    id, 
    first_name, 
    last_name, 
    role, 
    company_id, 
    company_inn, 
    assigned_site_ids
FROM user_profiles 
WHERE role IN ('siteManager', 'operatorPM', 'companyResponsible')
ORDER BY first_name;

-- 4. Включаем RLS обратно
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 5. Создаем правильные RLS политики
-- Политика для чтения собственного профиля
CREATE POLICY "Users can read their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

-- Политика для обновления собственного профиля
CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

-- Политика для администраторов (чтение всех профилей)
CREATE POLICY "Admins can read any profile" ON user_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() 
            AND up.role IN ('superAdmin', 'administrator')
        )
    );

-- Политика для администраторов (обновление всех профилей)
CREATE POLICY "Admins can update any profile" ON user_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() 
            AND up.role IN ('superAdmin', 'administrator')
        )
    );

-- Политика для ответственных лиц компании (чтение сотрудников своей компании)
CREATE POLICY "Company responsible can read employees" ON user_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() 
            AND up.role = 'companyResponsible'
            AND (
                up.company_id = user_profiles.company_id 
                OR up.company_inn = user_profiles.company_inn
            )
        )
    );

-- Политика для ответственных лиц компании (обновление сотрудников своей компании)
CREATE POLICY "Company responsible can update employees" ON user_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles up 
            WHERE up.id = auth.uid() 
            AND up.role = 'companyResponsible'
            AND (
                up.company_id = user_profiles.company_id 
                OR up.company_inn = user_profiles.company_inn
            )
        )
    );

-- 6. Проверяем созданные политики
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;
