-- Исправление данных для Марии Петровой и её сотрудников

-- 1. Обновляем company_id у Марии Петровой на правильный UUID из таблицы companies
UPDATE user_profiles 
SET company_id = (
    SELECT c.id 
    FROM companies c 
    WHERE c.company_inn = user_profiles.company_inn
)
WHERE first_name = 'Мария' AND last_name = 'Петрова'
  AND company_id IS NOT NULL;

-- 2. Обновляем company_id у всех сотрудников (siteManager, operatorPM) на правильный UUID
UPDATE user_profiles 
SET company_id = (
    SELECT c.id 
    FROM companies c 
    WHERE c.company_inn = user_profiles.company_inn
)
WHERE role IN ('siteManager', 'operatorPM')
  AND company_id IS NOT NULL
  AND company_inn IS NOT NULL;

-- 3. Проверяем результат
SELECT 
    id, 
    first_name, 
    last_name, 
    role, 
    company_id, 
    company_inn
FROM user_profiles 
WHERE first_name = 'Мария' AND last_name = 'Петрова'
   OR role IN ('siteManager', 'operatorPM')
ORDER BY first_name;
