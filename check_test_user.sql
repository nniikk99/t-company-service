-- Проверяем пользователя 'Test' и его компании
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.email,
    up.phone,
    up.role as profile_role,
    up.company_inn as profile_company_inn,
    uc.company_inn as user_company_inn,
    uc.company_name as user_company_name,
    uc.role as user_company_role,
    uc.status as user_company_status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.first_name ILIKE '%test%' 
   OR up.phone LIKE '%999%'
ORDER BY up.first_name, uc.company_inn;
