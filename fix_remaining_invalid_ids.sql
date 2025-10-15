-- Финальное исправление оставшихся некорректных ID
-- Выполните этот скрипт для исправления последних 3 площадок

-- 1. Сначала посмотрим, какие компании у нас есть
SELECT id, company_inn, name 
FROM companies 
ORDER BY name;

-- 2. Исправляем "t_company_id" - ищем компанию с похожим названием
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id = 't_company_id'
  AND (c.name ILIKE '%т%' OR c.name ILIKE '%t%' OR c.company_inn = '0000000001');

-- 3. Исправляем "demo_client_1" - ищем demo компанию
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id = 'demo_client_1'
  AND (c.name ILIKE '%demo%' OR c.name ILIKE '%тест%' OR c.company_inn = '0000000001');

-- 4. Если не нашли подходящие компании, создаем временную компанию
INSERT INTO companies (id, name, company_inn, description)
SELECT 
    '00000000-0000-0000-0000-000000000999'::uuid,
    'Временная компания',
    '9999999999',
    'Автоматически создана для исправления данных'
WHERE NOT EXISTS (
    SELECT 1 FROM companies WHERE company_inn = '9999999999'
);

-- 5. Привязываем оставшиеся площадки к временной компании
UPDATE sites 
SET company_id = '00000000-0000-0000-0000-000000000999'
WHERE company_id IN ('t_company_id', 'demo_client_1');

-- 6. Финальная проверка
SELECT 
    CASE 
        WHEN company_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
        THEN 'VALID UUID'
        ELSE 'INVALID UUID: ' || company_id
    END as uuid_status,
    COUNT(*) as count
FROM sites
GROUP BY uuid_status;

-- 7. Показываем все площадки с компаниями
SELECT 
    s.id as site_id,
    s.name as site_name,
    s.company_id,
    c.name as company_name,
    c.company_inn
FROM sites s
LEFT JOIN companies c ON s.company_id::uuid = c.id
ORDER BY c.name, s.name;
