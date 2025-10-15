-- Поиск и исправление всех дубликатов в user_profiles

-- 1. Находим дубликаты по номеру телефона
SELECT 
    phone,
    COUNT(*) as count,
    STRING_AGG(id::text, ', ') as user_ids,
    STRING_AGG(first_name || ' ' || last_name, ', ') as names
FROM user_profiles 
GROUP BY phone
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 2. Находим дубликаты по email
SELECT 
    email,
    COUNT(*) as count,
    STRING_AGG(id::text, ', ') as user_ids,
    STRING_AGG(first_name || ' ' || last_name, ', ') as names
FROM user_profiles 
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 3. Находим дубликаты по имени и фамилии
SELECT 
    first_name,
    last_name,
    COUNT(*) as count,
    STRING_AGG(id::text, ', ') as user_ids,
    STRING_AGG(phone, ', ') as phones
FROM user_profiles 
GROUP BY first_name, last_name
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 4. Показываем всех пользователей с проблемным номером телефона
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

-- 5. Показываем всех пользователей с проблемным номером телефона (нормализованный)
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

