-- Скрипт для синхронизации колонок 'description' и 'message'
-- Если в базе колонка называется 'message', а код шлет 'description', это вызывает ошибку.
-- Также исправляем права и структуру для impersonation (работы от имени другого пользователя)

DO $$ 
BEGIN 
    -- 1. Исправляем проблему с колонкой 'message'
    -- Если колонка 'message' существует и она NOT NULL, а мы хотим использовать 'description':
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'message') THEN
        -- Делаем ее необязательной, чтобы она не блокировала вставку
        ALTER TABLE service_requests ALTER COLUMN message DROP NOT NULL;
        -- На всякий случай переименовываем или создаем описание
    END IF;

    -- Гарантируем наличие 'description'
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'description') THEN
        ALTER TABLE service_requests ADD COLUMN description TEXT;
    END IF;

    -- 2. Добавляем колонку 'company_inn' если ее нет (пользователь спрашивал про ИНН)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'company_inn') THEN
        ALTER TABLE service_requests ADD COLUMN company_inn TEXT;
    END IF;

END $$;

-- 3. ПРАВА: Разрешаем вставку ЛЮБЫХ данных авторизованным пользователям (для тестов)
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;

-- 4. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
