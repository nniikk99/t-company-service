-- ПРОВЕРКА И ИСПРАВЛЕНИЕ ПОЛЯ assigned_site_ids

-- 1. Проверяем структуру таблицы user_profiles
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
ORDER BY ordinal_position;

-- 2. Проверяем текущие значения assigned_site_ids у сотрудников
SELECT 
    id, 
    first_name, 
    last_name, 
    role, 
    assigned_site_ids
FROM user_profiles 
WHERE role IN ('siteManager', 'operatorPM')
ORDER BY first_name;

-- 3. Если поле assigned_site_ids не существует, создаем его
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS assigned_site_ids TEXT[] DEFAULT '{}';

-- 4. Проверяем результат
SELECT 
    id, 
    first_name, 
    last_name, 
    role, 
    assigned_site_ids
FROM user_profiles 
WHERE role IN ('siteManager', 'operatorPM')
ORDER BY first_name;
