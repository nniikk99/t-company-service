-- Поиск пользователя по email и проверка его данных
-- В SQL Editor auth.uid() может быть NULL, поэтому ищем по email

-- ШАГ 1: Найдите пользователя по email (замените на реальный email)
-- Выполните этот запрос, заменив 'YOUR_EMAIL@example.com' на email ответственного лица
SELECT 
    'Пользователь по email' as info,
    id,
    email,
    first_name,
    last_name,
    phone,
    role,
    position,
    company_id,
    company_inn,
    is_active,
    created_at
FROM user_profiles
WHERE email = 'YOUR_EMAIL@example.com';  -- ЗАМЕНИТЕ на реальный email

-- ШАГ 2: Если пользователь найден, проверяем его company_id
-- Если company_id = NULL, это проблема!
SELECT 
    'Проверка company_id' as info,
    id,
    email,
    role,
    company_id,
    company_inn,
    CASE 
        WHEN company_id IS NULL THEN '❌ ПРОБЛЕМА: company_id = NULL'
        WHEN company_inn IS NULL THEN '⚠️ company_inn = NULL (может быть OK)'
        ELSE '✅ Данные заполнены'
    END as status
FROM user_profiles
WHERE email = 'YOUR_EMAIL@example.com';  -- ЗАМЕНИТЕ на реальный email

-- ШАГ 3: Если company_id = NULL, нужно обновить запись
-- Раскомментируйте и замените значения:
/*
UPDATE user_profiles
SET 
    company_id = 'ВАШ_COMPANY_ID',  -- ЗАМЕНИТЕ на ID компании
    company_inn = 'ВАШ_COMPANY_INN'  -- ЗАМЕНИТЕ на ИНН компании (если есть)
WHERE email = 'YOUR_EMAIL@example.com'  -- ЗАМЕНИТЕ на реальный email
AND company_id IS NULL;
*/

-- ШАГ 4: Проверяем все пользователи с ролью companyResponsible
SELECT 
    'Все ответственные лица' as info,
    id,
    email,
    first_name || ' ' || last_name as full_name,
    role,
    company_id,
    company_inn,
    is_active
FROM user_profiles
WHERE role = 'companyResponsible'
ORDER BY created_at DESC;

