-- RLS политики для service_requests и equipment
-- Дата: 2025-01-XX
-- Описание: Настройка Row Level Security для заявок и оборудования по ролям

-- ============================================
-- ПОЛИТИКИ ДЛЯ service_requests
-- ============================================

-- Включаем RLS для service_requests (если еще не включено)
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Удаляем старые политики, если они есть (для повторного применения)
DROP POLICY IF EXISTS "Поставщики видят свои заявки" ON service_requests;
DROP POLICY IF EXISTS "Создатели видят свои заявки" ON service_requests;
DROP POLICY IF EXISTS "Инженеры видят назначенные заявки" ON service_requests;
DROP POLICY IF EXISTS "Администраторы видят все заявки" ON service_requests;

-- Политика 1: Поставщики видят только заявки, где supplier_id = их user_id
CREATE POLICY "Поставщики видят свои заявки" ON service_requests
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
      AND service_requests.supplier_id = auth.uid()
    )
  );

-- Политика 2: Создатели заявок (operatorPM, siteManager, companyResponsible) видят свои заявки
CREATE POLICY "Создатели видят свои заявки" ON service_requests
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('operatorPM', 'siteManager', 'companyResponsible')
    )
  );

-- Политика 3: Инженеры видят только назначенные им заявки
CREATE POLICY "Инженеры видят назначенные заявки" ON service_requests
  FOR SELECT
  USING (
    assigned_engineer_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'engineer'
    )
  );

-- Политика 4: Администраторы видят все заявки
CREATE POLICY "Администраторы видят все заявки" ON service_requests
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- Политика 5: Поставщики могут обновлять заявки для назначения инженеров
CREATE POLICY "Поставщики могут назначать инженеров" ON service_requests
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
      AND service_requests.supplier_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
      AND service_requests.supplier_id = auth.uid()
    )
  );

-- Политика 6: Создатели могут создавать заявки
CREATE POLICY "Создатели могут создавать заявки" ON service_requests
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('operatorPM', 'siteManager', 'companyResponsible')
    )
  );

-- Политика 7: Инженеры могут обновлять свои заявки (начало/завершение работы)
CREATE POLICY "Инженеры могут обновлять свои заявки" ON service_requests
  FOR UPDATE
  USING (
    assigned_engineer_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'engineer'
    )
  )
  WITH CHECK (
    assigned_engineer_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'engineer'
    )
  );

-- ============================================
-- ПОЛИТИКИ ДЛЯ equipment
-- ============================================

-- Включаем RLS для equipment (если еще не включено)
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;

-- Удаляем старые политики, если они есть
DROP POLICY IF EXISTS "Поставщики видят свое оборудование" ON equipment;
DROP POLICY IF EXISTS "Компании видят свое оборудование" ON equipment;
DROP POLICY IF EXISTS "Администраторы видят все оборудование" ON equipment;

-- Политика 1: Поставщики видят оборудование, которое они поставили
CREATE POLICY "Поставщики видят свое оборудование" ON equipment
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
      AND equipment.supplier_id = auth.uid()
    )
  );

-- Политика 2: Компании видят свое оборудование
CREATE POLICY "Компании видят свое оборудование" ON equipment
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND (
        equipment.company_id = user_profiles.company_id
        OR equipment.company_inn = user_profiles.company_inn
      )
    )
  );

-- Политика 3: Администраторы видят все оборудование
CREATE POLICY "Администраторы видят все оборудование" ON equipment
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- Политика 4: Поставщики могут обновлять supplier_id своего оборудования
CREATE POLICY "Поставщики могут обновлять supplier_id" ON equipment
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
      AND equipment.supplier_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
    )
  );

-- Политика 5: Компании могут создавать и обновлять свое оборудование
CREATE POLICY "Компании могут управлять своим оборудованием" ON equipment
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('companyResponsible', 'siteManager')
      AND (
        equipment.company_id = user_profiles.company_id
        OR equipment.company_inn = user_profiles.company_inn
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('companyResponsible', 'siteManager')
      AND (
        equipment.company_id = user_profiles.company_id
        OR equipment.company_inn = user_profiles.company_inn
      )
    )
  );

