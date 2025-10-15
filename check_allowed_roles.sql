-- Проверяем, какие роли разрешены в user_profiles
-- Ошибка: companyResponsible не разрешена в check constraint

-- 1. Проверяем ограничения на роль в user_profiles
SELECT 
    tc.constraint_name, 
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'user_profiles' 
    AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%role%';

-- 2. Проверяем существующих пользователей и их роли
SELECT id, first_name, last_name, role, phone
FROM user_profiles 
ORDER BY created_at DESC;

-- 3. Если нужно, обновляем ограничение ролей
-- Сначала удаляем старое ограничение
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;

-- Создаем новое ограничение с правильными ролями
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check 
CHECK (role IN ('superAdmin', 'administrator', 'companyResponsible', 'siteManager', 'operatorPM', 'pendingApproval'));
