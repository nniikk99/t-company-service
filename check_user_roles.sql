-- Проверка ролей пользователей в базе данных
-- Проблема: пользователь показывает "Ожидает одобрения" вместо "Супер-администратор"

-- 1. Проверяем все роли в таблице user_profiles
SELECT 
    id,
    first_name,
    last_name,
    phone,
    role,
    company_inn,
    created_at
FROM user_profiles 
ORDER BY created_at DESC;

-- 2. Проверяем конкретно пользователя Михаила Басалыгина
SELECT 
    id,
    first_name,
    last_name,
    phone,
    role,
    company_inn,
    created_at
FROM user_profiles 
WHERE first_name ILIKE '%михаил%' 
   OR last_name ILIKE '%басалыгин%'
   OR phone LIKE '%+7%';

-- 3. Проверяем, какие роли есть в системе
SELECT DISTINCT role FROM user_profiles ORDER BY role;

-- 4. Если нужно исправить роль супер-админа
-- Раскомментируйте следующие строки и выполните:

-- UPDATE user_profiles 
-- SET role = 'superAdmin' 
-- WHERE id = '00000000-0000-0000-0000-000000000001' 
--    OR (first_name ILIKE '%михаил%' AND last_name ILIKE '%басалыгин%');

-- 5. Проверяем результат
-- SELECT id, first_name, last_name, role FROM user_profiles WHERE role = 'superAdmin';
