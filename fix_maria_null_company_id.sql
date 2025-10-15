-- ИСПРАВЛЕНИЕ ПРОБЛЕМЫ С МАРИЕЙ ПЕТРОВОЙ
-- У неё company_id = NULL, поэтому не находятся сотрудники

-- 1. Обновляем company_id у Марии Петровой на правильный UUID из таблицы companies
UPDATE user_profiles 
SET company_id = (
    SELECT c.id 
    FROM companies c 
    WHERE c.company_inn = '9876543210'
)
WHERE first_name = 'Мария' AND last_name = 'Петрова'
  AND company_id IS NULL;

-- 2. Проверяем результат
SELECT 
    id, 
    first_name, 
    last_name, 
    role, 
    company_id, 
    company_inn
FROM user_profiles 
WHERE first_name = 'Мария' AND last_name = 'Петрова';

-- 3. Проверяем, есть ли сотрудники у компании с ИНН 9876543210
SELECT 
    id, 
    first_name, 
    last_name, 
    role, 
    company_id, 
    company_inn
FROM user_profiles 
WHERE company_inn = '9876543210'
ORDER BY first_name;
