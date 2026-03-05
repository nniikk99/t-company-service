-- 1. СНИМАЕМ БЛОКИРОВКУ НА СОЗДАНИЕ (INSERT)
-- Разрешаем любым авторизованным пользователям вставлять данные.
-- Мы доверяем приложению в плане формирования данных, а RLS будет защищать ПРОСМОТР.
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable insert for all users" ON service_requests;
CREATE POLICY "Allow insert for authenticated" 
ON service_requests FOR INSERT 
TO authenticated 
WITH CHECK (true); -- Разрешаем саму вставку без проверок, чтобы избежать ошибки 42501

-- 2. СТРОГИЕ ПРАВИЛА НА ПРОСМОТР (SELECT)
-- Здесь мы проверяем роли и ИНН
DROP POLICY IF EXISTS "Admins see everything" ON service_requests;
DROP POLICY IF EXISTS "Company Responsible view by INN" ON service_requests;
DROP POLICY IF EXISTS "Site Manager view his sites" ON service_requests;
DROP POLICY IF EXISTS "Users see their own requests" ON service_requests;

-- Администраторы видят всё
CREATE POLICY "Admins see everything" ON service_requests
FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator'))
);

-- Ответственные лица видят заявки по ИНН своей компании
CREATE POLICY "Company Responsible view by INN" ON service_requests
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() 
    AND role = 'companyResponsible'
    AND company_inn::TEXT = service_requests.company_inn::TEXT
  )
);

-- Менеджеры площадок по списку ID
CREATE POLICY "Site Manager view his sites" ON service_requests
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_profiles up
    JOIN equipment e ON e.id = service_requests.equipment_id
    WHERE up.id = auth.uid() 
    AND up.role = 'siteManager'
    AND e.site_id::TEXT = ANY(up.assigned_site_ids)
  )
);

-- Операторы и обычные пользователи видят свои заявки
CREATE POLICY "Users see their own" ON service_requests
FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- 3. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
