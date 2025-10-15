-- Исправление таблицы user_companies - добавление недостающей колонки company_name

-- 1. Проверяем структуру таблицы user_companies
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_companies' 
ORDER BY ordinal_position;

-- 2. Добавляем колонку company_name если её нет
ALTER TABLE user_companies 
ADD COLUMN IF NOT EXISTS company_name VARCHAR(255);

-- 3. Обновляем существующие записи (если есть)
-- Получаем название компании из таблицы companies
UPDATE user_companies 
SET company_name = companies.name
FROM companies 
WHERE user_companies.company_id = companies.id 
AND user_companies.company_name IS NULL;

-- 4. Проверяем результат
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_companies' 
ORDER BY ordinal_position;

-- 5. Проверяем данные в таблице
SELECT id, user_id, company_id, company_name, company_inn, role, status 
FROM user_companies 
LIMIT 5;
