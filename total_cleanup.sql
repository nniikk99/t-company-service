-- ФИНАЛЬНЫЙ СКРИПТ РАЗБЛОКИРОВКИ (ИСПРАВЛЕННЫЙ)
-- Решает проблему: "cannot alter type of a column used in a policy definition"

-- 1. ОТКЛЮЧАЕМ БЕЗОПАСНОСТЬ И УДАЛЯЕМ ПОЛИТИКИ ПЕРВЫМ ДЕЛОМ
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;

DO $$ 
DECLARE 
    pol record;
BEGIN 
    -- Удаляем ВСЕ существующие политики, чтобы они не блокировали изменение типов колонок
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'service_requests') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON service_requests';
    END LOOP;
END $$;

-- 2. ТЕПЕРЬ МОЖНО СПОКОЙНО МЕНЯТЬ ТИПЫ
ALTER TABLE service_requests ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE service_requests ALTER COLUMN company_id TYPE TEXT;
ALTER TABLE service_requests ALTER COLUMN equipment_id TYPE TEXT;

-- 3. УДАЛЯЕМ ОГРАНИЧЕНИЯ (Foreign Keys)
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_user_id_fkey";
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_company_id_fkey";
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_equipment_id_fkey";
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_supplier_id_fkey";
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_assigned_engineer_id_fkey";

-- 4. ГАРАНТИРУЕМ НАЛИЧИЕ КОЛОНКИ ИНН
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'company_inn') THEN
        ALTER TABLE service_requests ADD COLUMN company_inn TEXT;
    END IF;
END $$;

-- 5. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
