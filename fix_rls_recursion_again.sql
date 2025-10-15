-- ИСПРАВЛЯЕМ RLS РЕКУРСИЮ (СНОВА)
-- Проблема вернулась, нужно исправить снова

-- Шаг 1: Отключаем RLS для user_profiles временно
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- Шаг 2: Удаляем все проблемные политики
DROP POLICY IF EXISTS "Allow all authenticated users to view user_profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow users to update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Allow users to insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile or admins can view all" ON user_profiles;

-- Шаг 3: Создаем простые и безопасные RLS политики
CREATE POLICY "Allow all authenticated users to view user_profiles" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "Allow users to update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow users to insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Шаг 4: Включаем RLS обратно
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Шаг 5: Проверяем, что политики созданы
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- Шаг 6: Тестовый запрос для проверки
SELECT COUNT(*) as total_users FROM user_profiles;
