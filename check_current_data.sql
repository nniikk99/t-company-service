-- Проверяем данные в таблице user_companies
SELECT id, user_id, company_id, company_name, company_inn, role, status 
FROM user_companies 
ORDER BY created_at DESC 
LIMIT 10;

-- Проверяем последние заявки на создание компаний
SELECT id, user_id, company_name, company_inn, requested_role, status, created_at
FROM company_requests 
ORDER BY created_at DESC 
LIMIT 5;

-- Проверяем последние уведомления
SELECT id, title, message, type, is_read, created_at
FROM notifications 
WHERE user_id = '00000000-0000-0000-0000-000000000001'
ORDER BY created_at DESC 
LIMIT 5;
