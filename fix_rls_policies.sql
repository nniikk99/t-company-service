-- Исправление RLS политик для правильной изоляции данных
-- Пользователи должны видеть только свои данные по company_inn

-- Включаем RLS для всех таблиц
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Удаляем старые политики
DROP POLICY IF EXISTS "Users can view their own sites based on company_inn and role" ON sites;
DROP POLICY IF EXISTS "Users can view their own equipment based on company_inn and role" ON equipment;
DROP POLICY IF EXISTS "CompanyResponsible and SuperAdmin can manage sites" ON sites;
DROP POLICY IF EXISTS "CompanyResponsible and SuperAdmin can manage equipment" ON equipment;
DROP POLICY IF EXISTS "PendingApproval cannot manage sites" ON sites;
DROP POLICY IF EXISTS "PendingApproval cannot manage equipment" ON equipment;

-- Политика для sites: Пользователи видят только свои компании
CREATE POLICY "Users can view sites of their companies"
ON sites FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = sites.company_inn
          AND uc.status = 'approved'
          AND uc.role <> 'pendingApproval'
    )
);

-- Политика для equipment: Пользователи видят только свое оборудование
CREATE POLICY "Users can view equipment of their companies"
ON equipment FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = equipment.company_inn
          AND uc.status = 'approved'
          AND uc.role <> 'pendingApproval'
    )
);

-- Политика для создания/обновления/удаления sites
CREATE POLICY "Users can manage sites of their companies"
ON sites FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = sites.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = sites.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
);

-- Политика для создания/обновления/удаления equipment
CREATE POLICY "Users can manage equipment of their companies"
ON equipment FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = equipment.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = equipment.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
);

-- Политика для service_requests (через equipment и sites)
CREATE POLICY "Users can view service requests of their companies"
ON service_requests FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        JOIN equipment e ON e.company_inn = uc.company_inn
        WHERE uc.user_id = auth.uid()
          AND e.id = service_requests.equipment_id
          AND uc.status = 'approved'
          AND uc.role <> 'pendingApproval'
    )
);

CREATE POLICY "Users can manage service requests of their companies"
ON service_requests FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        JOIN equipment e ON e.company_inn = uc.company_inn
        WHERE uc.user_id = auth.uid()
          AND e.id = service_requests.equipment_id
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager', 'operatorPM')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_companies uc
        JOIN equipment e ON e.company_inn = uc.company_inn
        WHERE uc.user_id = auth.uid()
          AND e.id = service_requests.equipment_id
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager', 'operatorPM')
    )
);

-- Проверяем результат
SELECT 'RLS policies updated successfully' as status;