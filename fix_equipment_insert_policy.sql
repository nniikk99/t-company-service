-- Исправление политики INSERT для equipment
-- Проблема: RLS блокирует создание оборудования (ошибка 42501: Unauthorized)
-- Причина: Политика не позволяет создавать оборудование ролям operatorPM, siteManager, companyResponsible

-- Удаляем старые политики INSERT
DROP POLICY IF EXISTS "Компании могут создавать оборудование" ON equipment;
DROP POLICY IF EXISTS "Allow authenticated users to create equipment" ON equipment;

-- Создаем правильную политику INSERT для equipment
-- Политика должна разрешать создание оборудования для:
-- 1. companyResponsible - ответственные лица компании
-- 2. siteManager - менеджеры площадок
-- 3. operatorPM - операторы ПМ
-- 4. superAdmin, administrator - администраторы
CREATE POLICY "Компании могут создавать оборудование" ON equipment
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN (
        'companyResponsible', 
        'siteManager', 
        'operatorPM',
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

-- Также нужно проверить политику "Компании могут управлять своим оборудованием"
-- Она может конфликтовать, если не включает operatorPM
-- Обновим её, чтобы она тоже включала operatorPM для INSERT
DROP POLICY IF EXISTS "Компании могут управлять своим оборудованием" ON equipment;

CREATE POLICY "Компании могут управлять своим оборудованием" ON equipment
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('companyResponsible', 'siteManager', 'operatorPM', 'superAdmin', 'administrator')
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
      AND user_profiles.role IN ('companyResponsible', 'siteManager', 'operatorPM', 'superAdmin', 'administrator')
      AND (
        equipment.company_id = user_profiles.company_id
        OR equipment.company_inn = user_profiles.company_inn
        OR user_profiles.role IN ('superAdmin', 'administrator')
      )
    )
  );

-- Проверяем текущие политики INSERT после исправления
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
        WHEN with_check IS NULL AND cmd = 'INSERT' THEN '❌ Нет условий в WITH CHECK'
        WHEN with_check::text LIKE '%auth.uid()%' AND with_check::text LIKE '%operatorPM%' THEN '✅ Включает operatorPM'
        WHEN with_check::text LIKE '%auth.uid()%' THEN '✅ Проверяет пользователя'
        ELSE '⚠️ Проверьте'
    END as status
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL')
ORDER BY cmd, policyname;
