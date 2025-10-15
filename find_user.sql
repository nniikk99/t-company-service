-- Проверяем всех пользователей в базе данных
-- Ищем вашего нового пользователя

-- 1. Показываем всех пользователей
SELECT 
    id, 
    first_name, 
    last_name, 
    phone, 
    email, 
    role, 
    company_inn,
    created_at
FROM user_profiles 
ORDER BY created_at DESC;

-- 2. Ищем пользователя по ID из ошибки
SELECT 
    id, 
    first_name, 
    last_name, 
    phone, 
    email, 
    role, 
    company_inn
FROM user_profiles 
WHERE id = 'bcc40db9-f3f6-46d2-a553-a1d8afc5fae1';

-- 3. Ищем пользователей по телефону (если знаете)
SELECT 
    id, 
    first_name, 
    last_name, 
    phone, 
    email, 
    role
FROM user_profiles 
WHERE phone LIKE '%981%' OR phone LIKE '%746%';

-- 4. Проверяем последних созданных пользователей
SELECT 
    id, 
    first_name, 
    last_name, 
    phone, 
    email, 
    role,
    created_at
FROM user_profiles 
WHERE created_at >= NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
