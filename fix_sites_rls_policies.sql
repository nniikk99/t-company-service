-- Исправление RLS политик для таблицы sites (v2)
-- Этот скрипт удаляет ВСЕ возможные дубликаты политик RLS перед созданием новых

-- ============================================
-- ШАГ 1: Удаление старых политик (в том числе русских имен)
-- ============================================

-- Удаляем по английским именам
DROP POLICY IF EXISTS "Users can view sites of their companies" ON sites;
DROP POLICY IF EXISTS "Users can manage sites of their companies" ON sites;
DROP POLICY IF EXISTS "Admins can manage all sites" ON sites;
DROP POLICY IF EXISTS "Allow all authenticated users to view sites" ON sites;
DROP POLICY IF EXISTS "Allow authenticated users to create sites" ON sites;
DROP POLICY IF EXISTS "Allow authenticated users to delete sites" ON sites;
DROP POLICY IF EXISTS "Allow authenticated users to update sites" ON sites;
DROP POLICY IF EXISTS "Users can create sites for their company" ON sites;
DROP POLICY IF EXISTS "Users can delete sites from their company" ON sites;
DROP POLICY IF EXISTS "Users can update sites from their company" ON sites;
DROP POLICY IF EXISTS "Users can view sites from their company" ON sites;

-- Удаляем по русским именам (которые мы создаем)
DROP POLICY IF EXISTS "Пользователи видят площадки своей компании" ON sites;
DROP POLICY IF EXISTS "Пользователи могут создавать площадки" ON sites;  -- <-- Это вызывало ошибку
DROP POLICY IF EXISTS "Пользователи могут обновлять площадки своей компании" ON sites;
DROP POLICY IF EXISTS "Пользователи могут удалять площадки своей компании" ON sites;
DROP POLICY IF EXISTS "Администраторы видят все площадки" ON sites;
DROP POLICY IF EXISTS "Пользователи могут управлять площадками своей компании" ON sites;

-- ============================================
-- ШАГ 2: Создание правильных политик
-- ============================================

-- Политика 1: SELECT
CREATE POLICY "Пользователи видят площадки своей компании" ON sites
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
    OR
    (
      EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('companyResponsible', 'siteManager', 'operatorPM')
        AND (
          (sites.company_id IS NOT NULL AND user_profiles.company_id IS NOT NULL AND sites.company_id::text = user_profiles.company_id::text)
          OR
          (sites.company_inn IS NOT NULL AND user_profiles.company_inn IS NOT NULL AND sites.company_inn = user_profiles.company_inn)
        )
      )
    )
  );

-- Политика 2: INSERT
CREATE POLICY "Пользователи могут создавать площадки" ON sites
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
    OR
    (
      EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('companyResponsible', 'siteManager')
        AND (
          (sites.company_id IS NOT NULL AND user_profiles.company_id IS NOT NULL AND sites.company_id::text = user_profiles.company_id::text)
          OR
          (sites.company_inn IS NOT NULL AND user_profiles.company_inn IS NOT NULL AND sites.company_inn = user_profiles.company_inn)
        )
      )
    )
  );

-- Политика 3: UPDATE
CREATE POLICY "Пользователи могут обновлять площадки своей компании" ON sites
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
    OR
    (
      EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('companyResponsible', 'siteManager')
        AND (
          (sites.company_id IS NOT NULL AND user_profiles.company_id IS NOT NULL AND sites.company_id::text = user_profiles.company_id::text)
          OR
          (sites.company_inn IS NOT NULL AND user_profiles.company_inn IS NOT NULL AND sites.company_inn = user_profiles.company_inn)
        )
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
    OR
    (
      EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('companyResponsible', 'siteManager')
        AND (
          (sites.company_id IS NOT NULL AND user_profiles.company_id IS NOT NULL AND sites.company_id::text = user_profiles.company_id::text)
          OR
          (sites.company_inn IS NOT NULL AND user_profiles.company_inn IS NOT NULL AND sites.company_inn = user_profiles.company_inn)
        )
      )
    )
  );

-- Политика 4: DELETE
CREATE POLICY "Пользователи могут удалять площадки своей компании" ON sites
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
    OR
    (
      EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('companyResponsible', 'siteManager')
        AND (
          (sites.company_id IS NOT NULL AND user_profiles.company_id IS NOT NULL AND sites.company_id::text = user_profiles.company_id::text)
          OR
          (sites.company_inn IS NOT NULL AND user_profiles.company_inn IS NOT NULL AND sites.company_inn = user_profiles.company_inn)
        )
      )
    )
  );

-- Включаем RLS
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
