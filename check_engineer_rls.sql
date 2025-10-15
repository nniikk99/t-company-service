-- Проверяем RLS политики для user_profiles
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- Проверяем, включен ли RLS для user_profiles
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'user_profiles';

-- Проверяем, можем ли мы видеть инженера напрямую
SELECT id, first_name, last_name, phone, role, is_active
FROM user_profiles 
WHERE role = 'engineer';
