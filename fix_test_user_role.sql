-- Исправляем роль пользователя Test с pendingApproval на companyResponsible
UPDATE user_profiles 
SET role = 'companyResponsible',
    updated_at = NOW()
WHERE id = '39fa2176-54c2-412f-9d01-52ef9cbf3c31';

-- Проверяем результат
SELECT 
    id,
    first_name,
    last_name,
    phone,
    role,
    company_inn
FROM user_profiles 
WHERE id = '39fa2176-54c2-412f-9d01-52ef9cbf3c31';
