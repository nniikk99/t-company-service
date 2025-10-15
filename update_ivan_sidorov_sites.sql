-- Обновление площадок для Ивана Сидорова
-- Оставляем только "Лемана Про" (fe8767e3-7490-4f5a-ab73-9eec66c235af)

-- 1. Проверяем текущее состояние
SELECT 
    id, 
    first_name, 
    last_name, 
    phone,
    role,
    assigned_site_ids,
    company_id,
    company_inn
FROM user_profiles 
WHERE id = '00000000-0000-0000-0000-000000000003';

-- 2. Обновляем assigned_site_ids (только Лемана Про)
UPDATE user_profiles
SET 
    assigned_site_ids = ARRAY['fe8767e3-7490-4f5a-ab73-9eec66c235af']::uuid[],
    updated_at = NOW()
WHERE id = '00000000-0000-0000-0000-000000000003';

-- 3. Проверяем результат
SELECT 
    id, 
    first_name, 
    last_name, 
    phone,
    role,
    assigned_site_ids,
    company_id,
    company_inn
FROM user_profiles 
WHERE id = '00000000-0000-0000-0000-000000000003';

-- 4. Проверяем, какое оборудование доступно на этой площадке
SELECT 
    id,
    name,
    site_id,
    company_id
FROM equipment
WHERE site_id = 'fe8767e3-7490-4f5a-ab73-9eec66c235af';

-- 5. Проверяем все площадки компании для справки
SELECT 
    id,
    name,
    address,
    company_id
FROM sites
WHERE company_id = '00000000-0000-0000-0000-000000000001'
ORDER BY name;

