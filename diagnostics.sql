-- ДИАГНОСТИЧЕСКИЙ СКРИПТ
-- Проверяем наличие пользователя
SELECT id, first_name, last_name, role, company_inn 
FROM user_profiles 
WHERE phone LIKE '%111%111%11%';

-- Проверяем структуру таблицы и ограничения
SELECT 
    conname AS constraint_name, 
    contype AS constraint_type,
    pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
WHERE t.relname = 'service_requests';

-- Проверяем наличие колонки company_inn
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'service_requests';
