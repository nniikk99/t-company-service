-- Проверка существования пользователя и исправление проблемы
-- Проблема: Пользователь не найден в user_profiles, поэтому RLS блокирует доступ

-- ШАГ 1: Проверяем, существует ли пользователь в auth.users
SELECT 
    'Пользователь в auth.users' as info,
    id,
    email,
    created_at
FROM auth.users
WHERE id = auth.uid();

-- ШАГ 2: Проверяем, есть ли пользователь в user_profiles
SELECT 
    'Пользователь в user_profiles' as info,
    id,
    email,
    role,
    company_id,
    company_inn
FROM user_profiles
WHERE id = auth.uid();

-- ШАГ 3: Если пользователь есть в auth.users, но НЕТ в user_profiles
-- Нужно создать запись в user_profiles
-- ВАЖНО: Замените значения на реальные данные пользователя

-- Пример создания профиля (РАСКОММЕНТИРУЙТЕ и заполните):
/*
INSERT INTO user_profiles (
    id,
    email,
    first_name,
    last_name,
    phone,
    role,
    position,
    company_id,
    company_inn,
    consent_to_personal_data,
    is_active
) 
SELECT 
    au.id,
    au.email,
    'Имя',  -- ЗАМЕНИТЕ
    'Фамилия',  -- ЗАМЕНИТЕ
    '+7 (999) 123-45-67',  -- ЗАМЕНИТЕ
    'companyResponsible',  -- Роль
    'Ответственное лицо',  -- Должность
    'ВАШ_COMPANY_ID',  -- ЗАМЕНИТЕ на ID компании
    'ВАШ_COMPANY_INN',  -- ЗАМЕНИТЕ на ИНН компании
    true,
    true
FROM auth.users au
WHERE au.id = auth.uid()
AND NOT EXISTS (
    SELECT 1 FROM user_profiles up WHERE up.id = au.id
);
*/

-- ШАГ 4: После создания профиля проверяем снова
SELECT 
    'Проверка после создания' as info,
    id,
    email,
    role,
    company_id,
    company_inn
FROM user_profiles
WHERE id = auth.uid();

