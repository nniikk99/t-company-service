-- Пошаговое исправление: сначала проверяем, потом создаем записи по одной

-- ШАГ 1: Проверяем текущую ситуацию (только SELECT, без INSERT)
SELECT 
    up.id as user_id,
    up.first_name,
    up.last_name,
    up.company_inn,
    up.company_name,
    up.role,
    COUNT(uc.id) as user_companies_count,
    -- Проверяем, есть ли уже ответственный для этой компании
    EXISTS(
        SELECT 1 FROM user_companies uc2 
        WHERE uc2.company_inn = up.company_inn 
        AND uc2.role = 'companyResponsible' 
        AND uc2.status = 'approved'
    ) as has_responsible_person
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.company_inn IS NOT NULL 
GROUP BY up.id, up.first_name, up.last_name, up.company_inn, up.company_name, up.role
ORDER BY up.created_at;
