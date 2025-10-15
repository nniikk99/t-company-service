-- Проверяем структуру таблицы companies
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'companies' 
ORDER BY ordinal_position;
