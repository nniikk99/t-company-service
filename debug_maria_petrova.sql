-- Отладка проблемы с Марией Петровой и её сотрудниками

-- 1. Проверяем данные Марии Петровой
SELECT 
    id, 
    first_name, 
    last_name, 
    phone, 
    role, 
    company_id, 
    company_inn,
    company_name
FROM user_profiles 
WHERE first_name = 'Мария' AND last_name = 'Петрова';

-- 2. Проверяем всех пользователей с ролями siteManager и operatorPM
SELECT 
    id, 
    first_name, 
    last_name, 
    phone, 
    role, 
    company_id, 
    company_inn,
    company_name
FROM user_profiles 
WHERE role IN ('siteManager', 'operatorPM')
ORDER BY first_name;

-- 3. Проверяем таблицу companies
SELECT id, name, company_inn FROM companies ORDER BY company_inn;

-- 4. Проверяем таблицу user_companies для Марии Петровой
SELECT 
    uc.user_id,
    uc.company_id,
    uc.company_inn,
    uc.company_name,
    uc.role,
    uc.status,
    up.first_name,
    up.last_name
FROM user_companies uc
JOIN user_profiles up ON uc.user_id = up.id
WHERE up.first_name = 'Мария' AND up.last_name = 'Петрова';

-- 5. Проверяем, есть ли сотрудники у компании Марии Петровой
-- Сначала найдем company_id Марии Петровой
WITH maria_company AS (
    SELECT company_id, company_inn 
    FROM user_profiles 
    WHERE first_name = 'Мария' AND last_name = 'Петрова'
)
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.role,
    up.company_id,
    up.company_inn
FROM user_profiles up
CROSS JOIN maria_company mc
WHERE up.role IN ('siteManager', 'operatorPM')
  AND (up.company_id = mc.company_id OR up.company_inn = mc.company_inn);
