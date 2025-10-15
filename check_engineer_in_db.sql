-- Проверяем инженера в базе данных
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.phone,
    up.role,
    up.company_inn,
    up.password_hash,
    uc.company_name,
    uc.status as user_company_status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.phone = '+7 (999) 123-45-67' 
   OR up.id = '83c74ef6-497f-4640-957a-463cda010065'
ORDER BY up.created_at;
