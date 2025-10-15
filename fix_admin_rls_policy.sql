-- ДОБАВЛЯЕМ СПЕЦИАЛЬНУЮ ПОЛИТИКУ ДЛЯ АДМИНИСТРАТОРОВ
-- Администраторы должны видеть всех инженеров

-- Удаляем старую политику для user_profiles
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;

-- Создаем новую политику: пользователи видят свой профиль ИЛИ админы видят всех
CREATE POLICY "Users can view their own profile or admins can view all" ON user_profiles
    FOR SELECT USING (
        auth.uid() = id 
        OR 
        (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('superAdmin', 'administrator')
    );

-- Проверяем результат
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.phone,
    up.role,
    up.is_active
FROM user_profiles up
WHERE up.role = 'engineer';
