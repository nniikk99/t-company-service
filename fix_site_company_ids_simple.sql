-- Упрощенный скрипт исправления данных
-- Выполняйте по одному блоку за раз

-- БЛОК 1: Проверяем текущее состояние
SELECT 'SITES TABLE' as table_name, company_id, COUNT(*) as count
FROM sites 
GROUP BY company_id
ORDER BY company_id;

-- БЛОК 2: Обновляем числовые ИНН
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id = c.company_inn
  AND sites.company_id ~ '^[0-9]+$';

-- БЛОК 3: Обновляем текстовые ID типа "demo_client_1"
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id LIKE 'demo_%'
  AND c.name ILIKE '%demo%';

-- БЛОК 4: Обновляем остальные текстовые ID
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND sites.company_id = c.company_inn::text;

-- БЛОК 5: Финальная проверка
SELECT 
    s.id as site_id,
    s.name as site_name,
    s.company_id,
    c.name as company_name,
    c.company_inn
FROM sites s
LEFT JOIN companies c ON (
    CASE 
        WHEN s.company_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
        THEN s.company_id::uuid = c.id
        ELSE s.company_id = c.company_inn::text
    END
)
ORDER BY c.name, s.name;

-- БЛОК 6: Проверка UUID статуса
SELECT 
    CASE 
        WHEN company_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
        THEN 'VALID UUID'
        ELSE 'INVALID UUID: ' || company_id
    END as uuid_status,
    COUNT(*) as count
FROM sites
GROUP BY uuid_status;
