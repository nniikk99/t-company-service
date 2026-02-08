-- Скрипт для исправления роли администратора
-- Выполните этот скрипт в SQL Editor в панели управления Supabase

-- 1. Обновляем всех пользователей со старой ролью 'admin' на новую 'superAdmin'
UPDATE user_profiles 
SET role = 'superAdmin' 
WHERE role = 'admin';

-- 2. Проверяем результат
SELECT id, first_name, last_name, email, role 
FROM user_profiles 
WHERE role = 'superAdmin';
