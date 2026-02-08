-- Исправление RLS политики для superAdmin с NULL company_id
-- Проблема: Политика проверяет company_id даже для superAdmin, что блокирует создание

-- Удаляем старую политику INSERT
DROP POLICY IF EXISTS "Компании могут создавать оборудование" ON equipment;

-- Создаем исправленную политику INSERT
-- Для superAdmin и administrator не требуется проверка company_id
CREATE POLICY "Компании могут создавать оборудование" ON equipment
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND (
        -- Администраторы могут создавать оборудование без проверки company_id
        user_profiles.role IN ('superAdmin', 'administrator')
        OR
        -- Для остальных ролей проверяем company_id или company_inn
        (
          user_profiles.role IN ('companyResponsible', 'siteManager', 'operatorPM')
          AND (
            -- Проверяем по company_id (если оба не NULL)
            (equipment.company_id IS NOT NULL 
             AND user_profiles.company_id IS NOT NULL
             AND equipment.company_id = user_profiles.company_id)
            OR 
            -- Проверяем по company_inn (если оба не NULL)
            (equipment.company_inn IS NOT NULL 
             AND user_profiles.company_inn IS NOT NULL
             AND equipment.company_inn = user_profiles.company_inn)
          )
        )
      )
    )
  );

-- Также обновляем политику "Компании могут управлять своим оборудованием"
DROP POLICY IF EXISTS "Компании могут управлять своим оборудованием" ON equipment;

CREATE POLICY "Компании могут управлять своим оборудованием" ON equipment
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND (
        -- Администраторы могут управлять всем оборудованием
        user_profiles.role IN ('superAdmin', 'administrator')
        OR
        -- Для остальных ролей проверяем company_id или company_inn
        (
          user_profiles.role IN ('companyResponsible', 'siteManager', 'operatorPM')
          AND (
            (equipment.company_id IS NOT NULL 
             AND user_profiles.company_id IS NOT NULL
             AND equipment.company_id = user_profiles.company_id)
            OR 
            (equipment.company_inn IS NOT NULL 
             AND user_profiles.company_inn IS NOT NULL
             AND equipment.company_inn = user_profiles.company_inn)
          )
        )
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND (
        -- Администраторы могут управлять всем оборудованием
        user_profiles.role IN ('superAdmin', 'administrator')
        OR
        -- Для остальных ролей проверяем company_id или company_inn
        (
          user_profiles.role IN ('companyResponsible', 'siteManager', 'operatorPM')
          AND (
            (equipment.company_id IS NOT NULL 
             AND user_profiles.company_id IS NOT NULL
             AND equipment.company_id = user_profiles.company_id)
            OR 
            (equipment.company_inn IS NOT NULL 
             AND user_profiles.company_inn IS NOT NULL
             AND equipment.company_inn = user_profiles.company_inn)
          )
        )
      )
    )
  );

-- Проверяем политики после исправления
SELECT 
    'Политики после исправления' as info,
    policyname,
    cmd,
    CASE 
        WHEN with_check::text LIKE '%superAdmin%' AND with_check::text LIKE '%OR%' THEN '✅ superAdmin без проверки company_id'
        WHEN with_check::text LIKE '%superAdmin%' THEN '⚠️ superAdmin с проверкой'
        ELSE '❌ Нет superAdmin'
    END as status
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL')
ORDER BY cmd, policyname;

