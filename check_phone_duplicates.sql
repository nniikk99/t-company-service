-- Проверяем дубликаты в нормализованном формате номера телефона

-- 1. Проверяем нормализованный формат (без пробелов и скобок)
SELECT 
    phone,
    COUNT(*) as count,
    STRING_AGG(id::text, ', ') as user_ids,
    STRING_AGG(first_name || ' ' || last_name, ', ') as names
FROM user_profiles 
GROUP BY phone
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 2. Проверяем все записи с номером 79817467395 (нормализованный формат)
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
WHERE phone = '79817467395'
ORDER BY created_at;

-- 3. Проверяем все записи с номером +7 (981) 746-73-95 (форматированный)
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
WHERE phone = '+7 (981) 746-73-95'
ORDER BY created_at;

-- 4. Проверяем все записи с номером, содержащим 79817467395
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
WHERE phone LIKE '%79817467395%'
ORDER BY created_at;

-- 5. Проверяем все записи с номером, содержащим 9817467395
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
WHERE phone LIKE '%9817467395%'
ORDER BY created_at;

