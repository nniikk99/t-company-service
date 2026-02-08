-- ФИНАЛЬНОЕ исправление политики INSERT для equipment
-- Проблема: RLS блокирует создание оборудования для operatorPM
-- Решение: Убедиться, что operatorPM включен во все политики

-- ШАГ 1: Удаляем старые политики INSERT
DROP POLICY IF EXISTS "Компании могут создавать оборудование" ON equipment;
DROP POLICY IF EXISTS "Allow authenticated users to create equipment" ON equipment;

-- ШАГ 2: Создаем правильную политику INSERT с operatorPM
CREATE POLICY "Компании могут создавать оборудование" ON equipment
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN (
        'companyResponsible', 
        'siteManager', 
        'operatorPM',  -- ВАЖНО: добавляем operatorPM
        'superAdmin', 
        'administrator'
      )
      AND (
        -- Проверяем, что company_id оборудования совпадает с company_id пользователя
        equipment.company_id = user_profiles.company_id
        OR 
        -- Или проверяем по company_inn
        (equipment.company_inn IS NOT NULL 
         AND equipment.company_inn = user_profiles.company_inn)
        OR
        -- Администраторы могут создавать оборудование для любой компании
        user_profiles.role IN ('superAdmin', 'administrator')
      )
    )
  );

-- ШАГ 3: Обновляем политику ALL, чтобы она тоже включала operatorPM
DROP POLICY IF EXISTS "Компании могут управлять своим оборудованием" ON equipment;

CREATE POLICY "Компании могут управлять своим оборудованием" ON equipment
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN (
        'companyResponsible', 
        'siteManager', 
        'operatorPM',  -- ВАЖНО: добавляем operatorPM
        'superAdmin', 
        'administrator'
      )
      AND (
        equipment.company_id = user_profiles.company_id
        OR equipment.company_inn = user_profiles.company_inn
        OR user_profiles.role IN ('superAdmin', 'administrator')
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN (
        'companyResponsible', 
        'siteManager', 
        'operatorPM',  -- ВАЖНО: добавляем operatorPM
        'superAdmin', 
        'administrator'
      )
      AND (
        equipment.company_id = user_profiles.company_id
        OR equipment.company_inn = user_profiles.company_inn
        OR user_profiles.role IN ('superAdmin', 'administrator')
      )
    )
  );

-- ШАГ 4: Проверяем результат
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 100)
        ELSE 'NULL'
    END as qual_preview,
    CASE 
        WHEN with_check IS NOT NULL THEN substring(with_check::text, 1, 150)
        ELSE 'NULL'
    END as with_check_preview,
    CASE 
        WHEN (cmd = 'INSERT' OR cmd = 'ALL')
             AND (qual::text LIKE '%operatorPM%' OR with_check::text LIKE '%operatorPM%')
        THEN '✅ Включает operatorPM'
        WHEN (cmd = 'INSERT' OR cmd = 'ALL')
             AND (qual::text LIKE '%siteManager%' OR with_check::text LIKE '%siteManager%')
             AND NOT (qual::text LIKE '%operatorPM%' OR with_check::text LIKE '%operatorPM%')
        THEN '❌ НЕ включает operatorPM'
        ELSE '⚠️ Проверьте'
    END as operatorPM_status
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL')
ORDER BY cmd, policyname;

