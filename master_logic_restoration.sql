-- ========================================================
-- ФИНАЛЬНЫЙ МАСТЕР-СКРИПТ ВОССТАНОВЛЕНИЯ ЛОГИКИ (2026-02-23)
-- ========================================================

-- 1. ОТКЛЮЧАЕМ RLS И УДАЛЯЕМ ВСЕ СТАРЫЕ ПОЛИТИКИ
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol record; BEGIN 
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'service_requests') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON service_requests';
    END LOOP;
END $$;

-- 2. УДАЛЯЕМ ВСЕ СТАРЫЕ ОГРАНИЧЕНИЯ (Foreign Keys) ПЕРЕД СМЕНОЙ ТИПОВ
DO $$ DECLARE r RECORD; BEGIN
    FOR r IN (SELECT constraint_name FROM information_schema.table_constraints WHERE table_name = 'service_requests' AND constraint_type = 'FOREIGN KEY') LOOP
        EXECUTE 'ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- 3. ЧИСТИМ "МУСОР" (Удаляем заявки, которых нет в справочниках, чтобы вернуть связи)
DELETE FROM service_requests 
WHERE (equipment_id IS NOT NULL AND equipment_id::TEXT NOT IN (SELECT id::TEXT FROM equipment))
   OR (user_id::TEXT NOT IN (SELECT id::TEXT FROM user_profiles));

-- 4. ВОЗВРАЩАЕМ ПРАВИЛЬНЫЕ ТИПЫ (UUID) ДЛЯ РАБОТЫ АВТОМАТИЧЕСКИХ JOIN-ОВ
ALTER TABLE service_requests ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE service_requests ALTER COLUMN equipment_id TYPE UUID USING equipment_id::UUID;
ALTER TABLE service_requests ALTER COLUMN assigned_engineer_id TYPE UUID USING assigned_engineer_id::UUID;

-- 5. ВОССТАНАВЛИВАЕМ СВЯЗИ (Foreign Keys) - Чтобы список заявок видел оборудование
ALTER TABLE service_requests ADD CONSTRAINT service_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE CASCADE;
ALTER TABLE service_requests ADD CONSTRAINT service_requests_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE CASCADE;
ALTER TABLE service_requests ADD CONSTRAINT service_requests_assigned_engineer_id_fkey FOREIGN KEY (assigned_engineer_id) REFERENCES user_profiles(id) ON DELETE SET NULL;

-- 6. ВКЛЮЧАЕМ УМНУЮ БЕЗОПАСНОСТЬ (RLS) ПО РОЛЯМ И ИНН
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Создание: разрешено всем авторизованным
CREATE POLICY "allow_insert" ON service_requests FOR INSERT TO authenticated WITH CHECK (true);

-- Просмотр: Администраторы
CREATE POLICY "admin_all" ON service_requests FOR SELECT TO authenticated 
USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator', 'admin')));

-- Просмотр: Ответственные (Видят только СВОЮ компанию по ИНН)
CREATE POLICY "company_responsible_view" ON service_requests FOR SELECT TO authenticated
USING (
  company_inn = (SELECT company_inn FROM user_profiles WHERE id = auth.uid())
);

-- Просмотр: Менеджеры площадок (По списку привязанных площадок)
CREATE POLICY "site_manager_view" ON service_requests FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_profiles up
    JOIN equipment e ON e.id = service_requests.equipment_id
    WHERE up.id = auth.uid() 
    AND up.role = 'siteManager'
    AND e.site_id::TEXT = ANY(up.assigned_site_ids::TEXT[])
  )
);

-- Просмотр: Операторы и другие (Видят свои созданные заявки)
CREATE POLICY "owner_view" ON service_requests FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 7. ОБНОВЛЕНИЕ КЭША СУПАБЕЙС
NOTIFY pgrst, 'reload schema';
