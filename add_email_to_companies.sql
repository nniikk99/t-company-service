-- Добавляем колонку email в таблицу companies, если её нет
ALTER TABLE companies 
ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Обновляем существующие записи
UPDATE companies 
SET email = 'info@testcompany.com' 
WHERE company_inn = '0000000001' AND email IS NULL;
