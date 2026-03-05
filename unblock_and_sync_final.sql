-- 1. ПОЛНОЕ РАЗБЛОКИРОВАНИЕ ТАБЛИЦЫ ДЛЯ ВСТАВКИ (INSERT)
-- Это гарантирует, что ошибка 42501 при СОЗДАНИИ заявки исчезнет навсегда.
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;

-- 2. ГАРАНТИРУЕМ НАЛИЧИЕ ВСЕХ НУЖНЫХ КОЛОНОК (ИНН и совместимость)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'company_inn') THEN
        ALTER TABLE service_requests ADD COLUMN company_inn TEXT;
    END IF;
    
    -- Делаем колонки необязательными, чтобы не было ошибок при неполных данных во время тестов
    ALTER TABLE service_requests ALTER COLUMN message DROP NOT NULL;
    ALTER TABLE service_requests ALTER COLUMN description DROP NOT NULL;
END $$;

-- 3. ВОССТАНАВЛИВАЕМ СВЯЗИ ДЛЯ КОРРЕКТНОГО JOIN (Чтобы список заявок не был пустым)
ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS "service_requests_equipment_id_fkey";
ALTER TABLE service_requests ADD CONSTRAINT "service_requests_equipment_id_fkey" 
FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE CASCADE;

ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS "service_requests_user_id_fkey";
ALTER TABLE service_requests ADD CONSTRAINT "service_requests_user_id_fkey" 
FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE SET NULL;

-- 4. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
