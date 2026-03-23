-- Проверяем как реально называются колонки в service_requests
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'service_requests'
ORDER BY ordinal_position;
