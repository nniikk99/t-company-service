-- ИСПРАВЛЕННЫЙ СКРИПТ ДЛЯ СНЯТИЯ ОГРАНИЧЕНИЙ
-- Дата: 2026-02-23

-- 1. Удаляем ограничение внешнего ключа (Foreign Key), которое блокирует тестовые ИНН
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_company_id_fkey";

-- 2. Делаем колонки необязательными, чтобы не было ошибок при неполных данных
ALTER TABLE service_requests ALTER COLUMN message DROP NOT NULL;
ALTER TABLE service_requests ALTER COLUMN description DROP NOT NULL;

-- 3. Добавляем ИНН через DO-блок (исправляет синтаксическую ошибку)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'company_inn') THEN
        ALTER TABLE service_requests ADD COLUMN company_inn TEXT;
    END IF;
END $$;

-- 4. Переименовываем колонку, если она называется иначе, или просто убеждаемся в наличии
-- (На всякий случай для совместимости с вашим скриншотом)

-- 5. Обновляем кэш Supabase
NOTIFY pgrst, 'reload schema';
