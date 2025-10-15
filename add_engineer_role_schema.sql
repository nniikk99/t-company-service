-- БЕЗОПАСНОЕ ДОБАВЛЕНИЕ РОЛИ "ИНЖЕНЕР" И ПОЛЕЙ ДЛЯ НАЗНАЧЕНИЯ ЗАЯВОК

-- 1. Проверяем текущие роли в user_profiles
SELECT DISTINCT role FROM user_profiles;

-- 2. Добавляем роль 'engineer' в enum (если используется enum)
-- Если роли хранятся как VARCHAR, то этот шаг не нужен
-- ALTER TYPE user_role_enum ADD VALUE 'engineer';

-- 3. Добавляем поле assigned_engineer_id в таблицу service_requests
ALTER TABLE service_requests 
ADD COLUMN IF NOT EXISTS assigned_engineer_id UUID REFERENCES user_profiles(id);

-- 4. Добавляем поле для комментариев инженера
ALTER TABLE service_requests 
ADD COLUMN IF NOT EXISTS engineer_comment TEXT;

-- 5. Добавляем поле для времени начала работы инженера
ALTER TABLE service_requests 
ADD COLUMN IF NOT EXISTS engineer_started_at TIMESTAMP WITH TIME ZONE;

-- 6. Добавляем поле для времени завершения работы инженера
ALTER TABLE service_requests 
ADD COLUMN IF NOT EXISTS engineer_completed_at TIMESTAMP WITH TIME ZONE;

-- 7. Проверяем структуру таблицы service_requests
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'service_requests' 
ORDER BY ordinal_position;

-- 8. Создаем индекс для быстрого поиска заявок по инженеру
CREATE INDEX IF NOT EXISTS idx_service_requests_assigned_engineer 
ON service_requests(assigned_engineer_id) 
WHERE assigned_engineer_id IS NOT NULL;
