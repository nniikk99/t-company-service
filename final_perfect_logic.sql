-- ==========================================
-- ФИНАЛЬНЫЙ СКРИПТ: ЛОГИКА И ПРАВА ДОСТУПА
-- ==========================================

-- 1. ОТКЛЮЧАЕМ ПРОВЕРКИ И ОЧИЩАЕМ СТАРЫЕ ПРАВИЛА
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;

DO $$ 
DECLARE pol record;
BEGIN 
    -- Удаляем все политики
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'service_requests') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON service_requests';
    END LOOP;
END $$;

-- 2. УДАЛЯЕМ ВСЕ СТАРЫЕ ОГРАНИЧЕНИЯ (Foreign Keys)
DO $$ 
DECLARE r RECORD;
BEGIN
    FOR r IN (SELECT constraint_name 
              FROM information_schema.table_constraints 
              WHERE table_name = 'service_requests' AND constraint_type = 'FOREIGN KEY') 
    LOOP
        EXECUTE 'ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- 3. ЧИСТИМ ДАННЫЕ (Удаляем некорректные записи, чтобы вернуть связи)
DELETE FROM service_requests 
WHERE (equipment_id IS NOT NULL AND equipment_id::TEXT NOT IN (SELECT id::TEXT FROM equipment))
   OR (user_id::TEXT NOT IN (SELECT id::TEXT FROM user_profiles));

-- 4. ПРИВОДИМ ТИПЫ К UUID (для корректной работы Supabase и Join-ов)
ALTER TABLE service_requests ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE service_requests ALTER COLUMN equipment_id TYPE UUID USING equipment_id::UUID;
ALTER TABLE service_requests ALTER COLUMN company_id TYPE UUID USING company_id::UUID;

-- 5. ВОССТАНАВЛИВАЕМ СВЯЗИ (Foreign Keys)
ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE CASCADE;

ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE CASCADE;

-- 6. ГАРАНТИРУЕМ НАЛИЧИЕ КОЛОНКИ ИНН
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'company_inn') THEN
        ALTER TABLE service_requests ADD COLUMN company_inn TEXT;
    END IF;
END $$;

-- 7. НАСТРАИВАЕМ ПРАВА ДОСТУПА (RLS) ПО ЛОГИКЕ ПОЛЬЗОВАТЕЛЯ
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Политика: Создание заявок (разрешено всем авторизованным)
CREATE POLICY "service_requests_insert" ON service_requests
FOR INSERT TO authenticated
WITH CHECK (true);

-- Политика: Администраторы видят ВСЁ
CREATE POLICY "service_requests_admin_all" ON service_requests
FOR SELECT TO authenticated
USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator'))
);

-- Политика: Ответственное лицо видит заявки своей компании (по ИНН)
CREATE POLICY "service_requests_company_view" ON service_requests
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role = 'companyResponsible'
        AND company_inn::TEXT = service_requests.company_inn::TEXT
    )
);

-- Политика: Менеджер площадки видит заявки своих площадок
CREATE POLICY "service_requests_site_manager_view" ON service_requests
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up
        JOIN equipment e ON e.id = service_requests.equipment_id
        WHERE up.id = auth.uid() 
        AND up.role = 'siteManager'
        AND e.site_id::TEXT = ANY(up.assigned_site_ids::TEXT[])
    )
);

-- Политика: Оператор и другие пользователи видят свои созданные заявки
CREATE POLICY "service_requests_owner_view" ON service_requests
FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- 8. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
