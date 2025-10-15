-- Проверка дублирующихся записей Ивана Сидорова
-- Ищем всех пользователей с именем "Иван Сидоров"

SELECT 
    id, 
    first_name, 
    last_name, 
    phone,
    email,
    role,
    assigned_site_ids,
    company_id,
    company_inn,
    created_at,
    updated_at
FROM user_profiles 
WHERE first_name = 'Иван' AND last_name = 'Сидоров'
ORDER BY created_at;

-- Проверяем, есть ли дубликаты по телефону
SELECT 
    phone,
    COUNT(*) as count
FROM user_profiles 
WHERE phone = '+7 (495) 987-65-43'
GROUP BY phone
HAVING COUNT(*) > 1;

-- Проверяем, есть ли дубликаты по email
SELECT 
    email,
    COUNT(*) as count
FROM user_profiles 
WHERE email = 'ivan@lenta.ru'
GROUP BY email
HAVING COUNT(*) > 1;

-- Удаляем дублирующиеся записи (оставляем только самую новую)
-- Сначала посмотрим, какие ID у нас есть
SELECT 
    id,
    created_at,
    updated_at
FROM user_profiles 
WHERE first_name = 'Иван' AND last_name = 'Сидоров'
ORDER BY updated_at DESC;

-- Удаляем старые дубликаты (замените ID на актуальные из запроса выше)
-- DELETE FROM user_profiles 
-- WHERE id IN ('старый_id_1', 'старый_id_2') 
-- AND first_name = 'Иван' AND last_name = 'Сидоров';

-- Проверяем результат после удаления
SELECT 
    id, 
    first_name, 
    last_name, 
    phone,
    email,
    role,
    assigned_site_ids,
    company_id,
    company_inn
FROM user_profiles 
WHERE first_name = 'Иван' AND last_name = 'Сидоров';

