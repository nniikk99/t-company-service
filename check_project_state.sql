-- Проверяем общее состояние проекта и синхронизацию с БД
-- Шаг 1: Проверяем всех пользователей с телефоном +7 (999) 123-45-67
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.phone,
    up.role,
    up.password_hash,
    up.company_inn,
    uc.company_name,
    uc.status as user_company_status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.phone = '+7 (999) 123-45-67'
ORDER BY up.created_at;

-- Шаг 2: Проверяем всех инженеров
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.phone,
    up.role,
    uc.company_name,
    uc.status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
WHERE up.role = 'engineer'
ORDER BY up.created_at;

-- Шаг 3: Проверяем RLS политики для таблицы sites
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'sites';

-- Шаг 4: Проверяем структуру таблицы sites
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'sites' 
ORDER BY ordinal_position;
