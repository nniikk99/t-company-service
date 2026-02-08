-- Комплексное отключение RLS для таблиц user_profiles и companies
-- Выполните весь этот скрипт целиком в Supabase SQL Editor

-- === USER_PROFILES ===

-- Шаг 1: Удаляем все существующие политики RLS для user_profiles
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON user_profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON user_profiles;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON user_profiles;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON user_profiles;
DROP POLICY IF EXISTS "Allow users to view profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow users to insert profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow users to update profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow users to delete profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admin can insert profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admin can update all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admin can delete all profiles" ON user_profiles;
DROP POLICY IF EXISTS "SuperAdmin can do everything" ON user_profiles;

-- Шаг 2: Отключаем RLS для user_profiles
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- === COMPANIES ===

-- Шаг 3: Удаляем все существующие политики RLS для companies
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON companies;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON companies;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON companies;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON companies;
DROP POLICY IF EXISTS "Allow users to view companies" ON companies;
DROP POLICY IF EXISTS "Allow users to insert companies" ON companies;
DROP POLICY IF EXISTS "Allow users to update companies" ON companies;
DROP POLICY IF EXISTS "Allow users to delete companies" ON companies;
DROP POLICY IF EXISTS "Users can view their own company" ON companies;
DROP POLICY IF EXISTS "Users can update their own company" ON companies;
DROP POLICY IF EXISTS "Admin can view all companies" ON companies;
DROP POLICY IF EXISTS "Admin can insert companies" ON companies;
DROP POLICY IF EXISTS "Admin can update all companies" ON companies;
DROP POLICY IF EXISTS "Admin can delete all companies" ON companies;
DROP POLICY IF EXISTS "SuperAdmin can do everything" ON companies;

-- Шаг 4: Отключаем RLS для companies
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;

-- Проверка: показываем текущий статус RLS для обеих таблиц
SELECT 
    tablename, 
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('user_profiles', 'companies')
ORDER BY tablename;
