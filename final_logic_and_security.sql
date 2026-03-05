-- 1. ОЧИСТКА ДАННЫХ ПЕРЕД ВОССТАНОВЛЕНИЕМ СВЯЗЕЙ
-- Удаляем записи, которые не соответствуют существующим пользователям или оборудованию
DELETE FROM service_requests 
WHERE user_id::TEXT NOT IN (SELECT id::TEXT FROM user_profiles) 
   OR (equipment_id IS NOT NULL AND equipment_id::TEXT NOT IN (SELECT id::TEXT FROM equipment));

-- 2. ВОССТАНОВЛЕНИЕ СТРОГИХ СВЯЗЕЙ (Для работы JOIN в приложении)
-- Сначала удаляем, если существуют, чтобы не было ошибок
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_equipment_id_fkey";
ALTER TABLE "service_requests" DROP CONSTRAINT IF EXISTS "service_requests_user_id_fkey";

-- Добавляем заново
ALTER TABLE "service_requests" 
ADD CONSTRAINT "service_requests_equipment_id_fkey" 
FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE CASCADE;

ALTER TABLE "service_requests" 
ADD CONSTRAINT "service_requests_user_id_fkey" 
FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE SET NULL;

-- 3. ВКЛЮЧАЕМ УМНУЮ БЕЗОПАСНОСТЬ (RLS)
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Удаляем все старые политики
DROP POLICY IF EXISTS "Global Access" ON service_requests;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON service_requests;
DROP POLICY IF EXISTS "Admins see everything" ON service_requests;
DROP POLICY IF EXISTS "Company Responsible view by INN" ON service_requests;
DROP POLICY IF EXISTS "Site Manager view his sites" ON service_requests;
DROP POLICY IF EXISTS "Users see their own requests" ON service_requests;
DROP POLICY IF EXISTS "Enable insert for all users" ON service_requests;

-- ПРАВИЛО 1: Админы видят всё
CREATE POLICY "Admins see everything" ON service_requests
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator'))
  );

-- ПРАВИЛО 2: Ответственное лицо видит заявки своей компании по ИНН
CREATE POLICY "Company Responsible view by INN" ON service_requests
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
      AND user_profiles.role = 'companyResponsible'
      AND user_profiles.company_inn::TEXT = service_requests.company_inn::TEXT
    )
  );

-- ПРАВИЛО 3: Менеджер площадки видит заявки своих площадок (с исправлением типов UUID -> TEXT)
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

-- ПРАВИЛО 4: Оператор ПМ и остальные видят свои созданные заявки
CREATE POLICY "Users see their own requests" ON service_requests
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ПРАВИЛО 5: Разрешаем создавать заявки всем авторизованным (с заполнением своего ID)
CREATE POLICY "Enable insert for all users" ON service_requests
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')));

-- 4. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
