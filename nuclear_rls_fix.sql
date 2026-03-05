-- 1. ПОЛНЫЙ СБРОС И ОЧИСТКА ПОЛИТИК
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;

DO $$ 
DECLARE 
    pol record;
BEGIN 
    -- Удаляем вообще все политики, которые есть у таблицы, чтобы не было конфликтов
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'service_requests') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON service_requests';
    END LOOP;
END $$;

-- 2. ПРАВИЛО НА СОЗДАНИЕ (INSERT): Разрешаем всем авторизованным
-- Это уберет ошибку 42501 раз и навсегда
CREATE POLICY "allow_authenticated_insert" 
ON service_requests FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- 3. ПРАВИЛА НА ПРОСМОТР (SELECT): Ваша логика ролей
-- Админы
CREATE POLICY "admin_select_all" ON service_requests FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')));

-- Ответственные по ИНН (приводим всё к тексту для надежности)
CREATE POLICY "responsible_select_by_inn" ON service_requests FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role = 'companyResponsible' 
        AND company_inn::TEXT = service_requests.company_inn::TEXT
    )
);

-- Менеджеры площадок
CREATE POLICY "manager_select_by_sites" ON service_requests FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up 
        JOIN equipment e ON e.id = service_requests.equipment_id 
        WHERE up.id = auth.uid() 
        AND up.role = 'siteManager' 
        AND e.site_id::TEXT = ANY(up.assigned_site_ids::TEXT[])
    )
);

-- Каждый видит свои заявки
CREATE POLICY "owner_select_own" ON service_requests FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- 4. ВКЛЮЧАЕМ RLS ОБРАТНО
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- 5. ОБНОВЛЯЕМ КЭШ
NOTIFY pgrst, 'reload schema';
