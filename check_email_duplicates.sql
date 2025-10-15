-- Проверяем дубликаты по email

-- 1. Находим дубликаты по email
SELECT 
    email,
    COUNT(*) as count,
    STRING_AGG(id::text, ', ') as user_ids,
    STRING_AGG(first_name || ' ' || last_name, ', ') as names
FROM user_profiles 
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 2. Проверяем все записи с email nniikk.9@mail.ru
SELECT 
    id,
    first_name,
    last_name,
    phone,
    email,
    role,
    company_id,
    created_at,
    updated_at
FROM user_profiles 
WHERE email = 'nniikk.9@mail.ru'
ORDER BY created_at;

-- 3. Проверяем все записи с email admin@t-company.ru
SELECT 
    id,
    first_name,
    last_name,
    phone,
    email,
    role,
    company_id,
    created_at,
    updated_at
FROM user_profiles 
WHERE email = 'admin@t-company.ru'
ORDER BY created_at;

