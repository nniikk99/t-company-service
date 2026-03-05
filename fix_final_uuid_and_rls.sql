-- ========================================================
-- ФИНАЛЬНЫЙ СКРИПТ: ИСПРАВЛЕНИЕ СВЯЗЕЙ И ТИПОВ (БЕЗ ОШИБОК)
-- ========================================================

-- 1. ВРЕМЕННО ОТКЛЮЧАЕМ БЕЗОПАСНОСТЬ И УДАЛЯЕМ ПОЛИТИКИ
-- Это нужно, чтобы позволить PostgreSQL изменить типы колонок
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;

DO $$ 
DECLARE pol record;
BEGIN 
    -- Удаляем все политики, которые могут блокировать изменение типа колонок
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'service_requests') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON service_requests';
    END LOOP;
END $$;

-- 2. УДАЛЯЕМ ВСЕ ВНЕШНИЕ КЛЮЧИ (СВЯЗИ)
DO $$ 
DECLARE r RECORD;
BEGIN
    FOR r IN (SELECT constraint_name FROM information_schema.table_constraints WHERE table_name = 'service_requests' AND constraint_type = 'FOREIGN KEY') LOOP
        EXECUTE 'ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- 3. ЧИСТИМ ДАННЫЕ (Удаляем заявки, ссылающиеся на несуществующие объекты)
-- Это необходимо для успешного создания Foreign Keys
DELETE FROM service_requests 
WHERE (equipment_id IS NOT NULL AND equipment_id::TEXT NOT IN (SELECT id::TEXT FROM equipment))
   OR (user_id::TEXT NOT IN (SELECT id::TEXT FROM user_profiles));

-- 4. МЕНЯЕМ ТИПЫ КОЛОНОК НА UUID (обязательно для автоматических Join-ов)
ALTER TABLE service_requests ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE service_requests ALTER COLUMN equipment_id TYPE UUID USING equipment_id::UUID;
ALTER TABLE service_requests ALTER COLUMN assigned_engineer_id TYPE UUID USING assigned_engineer_id::UUID;
ALTER TABLE service_requests ALTER COLUMN company_id TYPE UUID USING company_id::UUID;

-- 5. ВОССТАНАВЛИВАЕМ СВЯЗИ (Foreign Keys) С ИМЕНАМИ, КОТОРЫЕ ЖДЕТ ПРИЛОЖЕНИЕ
-- Это уберет ошибку PGRST200
ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_assigned_engineer_id_fkey 
FOREIGN KEY (assigned_engineer_id) REFERENCES user_profiles(id) ON DELETE SET NULL;

ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE CASCADE;

ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_equipment_id_fkey 
FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE CASCADE;

-- 6. ВОССТАНАВЛИВАЕМ УМНУЮ БЕЗОПАСНОСТЬ (RLS)
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Создание заявок разрешено всем авторизованным
CREATE POLICY "service_requests_insert_policy" ON service_requests FOR INSERT TO authenticated WITH CHECK (true);

-- Администраторы видят всё
CREATE POLICY "service_requests_admin_select" ON service_requests FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')));

-- Ответственные по ИНН
CREATE POLICY "service_requests_responsible_select" ON service_requests FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'companyResponsible' AND company_inn = service_requests.company_inn));

-- Менеджеры площадок
CREATE POLICY "service_requests_manager_select" ON service_requests FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM user_profiles up JOIN equipment e ON e.id = service_requests.equipment_id 
       WHERE up.id = auth.uid() AND up.role = 'siteManager' AND e.site_id::TEXT = ANY(up.assigned_site_ids::TEXT[])));

-- Каждый видит свои заявки
CREATE POLICY "service_requests_user_select" ON service_requests FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 7. ОБНОВЛЕНИЕ КЭША СУПАБЕЙС
NOTIFY pgrst, 'reload schema';
