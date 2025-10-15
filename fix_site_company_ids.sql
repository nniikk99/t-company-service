-- Исправление данных в базе для корректной работы системы назначения площадок
-- Выполните этот скрипт ПОСЛЕ основного скрипта setup_site_assignment_system.sql

-- 1. Проверяем текущее состояние данных
SELECT 'SITES TABLE' as table_name, company_id, COUNT(*) as count
FROM sites 
GROUP BY company_id
ORDER BY company_id;

SELECT 'COMPANIES TABLE' as table_name, id, company_inn, name
FROM companies 
ORDER BY name;

-- 2. Обновляем company_id в таблице sites для тестовых данных
-- Заменяем текстовые ID на соответствующие UUID из таблицы companies
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id = c.company_inn
  AND sites.company_id ~ '^[0-9]+$'; -- Только числовые ИНН

-- 3. Проверяем результат обновления
SELECT 'AFTER UPDATE - SITES' as table_name, company_id, COUNT(*) as count
FROM sites 
GROUP BY company_id
ORDER BY company_id;

-- 4. Если есть площадки с текстовыми ID типа "demo_client_1", обновляем их
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id LIKE 'demo_%'
  AND c.name ILIKE '%demo%';

-- 4.1. Обновляем все остальные текстовые ID, которые не являются UUID
UPDATE sites 
SET company_id = c.id::text
FROM companies c
WHERE sites.company_id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND sites.company_id = c.company_inn::text;

-- 5. Финальная проверка
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

-- 6. Проверяем, что все площадки теперь имеют корректные UUID
SELECT 
    CASE 
        WHEN company_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
        THEN 'VALID UUID'
        ELSE 'INVALID UUID: ' || company_id
    END as uuid_status,
    COUNT(*) as count
FROM sites
GROUP BY uuid_status;
