-- Финальное исправление проблем безопасности RLS политик
-- Удаление опасных широких политик и исправление политик без условий

-- ============================================
-- ШАГ 1: Удаление ОПАСНОЙ политики просмотра
-- ============================================

-- Удаляем политику, позволяющую ВСЕМ видеть ВСЁ оборудование
DROP POLICY IF EXISTS "Allow all authenticated users to view equipment" ON equipment;

-- ============================================
-- ШАГ 2: Удаление или исправление политик INSERT без условий
-- ============================================

-- Удаляем старую широкую политику создания
DROP POLICY IF EXISTS "Allow authenticated users to create equipment" ON equipment;

-- Удаляем дублирующую политику (у нас уже есть более точная)
-- НО: оставим "Компании могут создавать оборудование" если она нужна для WITH CHECK
-- Проверим, что она имеет правильные условия в WITH CHECK

-- Если политика "Компании могут создавать оборудование" существует без условий,
-- пересоздадим её с правильными условиями
DROP POLICY IF EXISTS "Компании могут создавать оборудование" ON equipment;

-- Создаем правильную политику для INSERT с проверкой условий
CREATE POLICY "Компании могут создавать оборудование" ON equipment
  FOR INSERT
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

-- ============================================
-- ШАГ 3: Проверка и исправление политики для service_requests
-- ============================================

-- Проверяем политику создания заявок
-- Если у неё нет условий, добавим их
DROP POLICY IF EXISTS "Создатели могут создавать заявки" ON service_requests;

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

-- ============================================
-- ПРОВЕРКА: Просмотр всех политик после исправлений
-- ============================================

-- Проверяем безопасность всех политик для equipment
SELECT 
    'equipment' as table_name,
    policyname,
    cmd,
    roles,
    CASE 
        WHEN qual::text = 'true' THEN '❌ ОПАСНО: без ограничений'
        WHEN qual IS NULL AND cmd = 'SELECT' THEN '❌ ОПАСНО: видно всё'
        WHEN qual IS NULL AND cmd = 'INSERT' THEN '⚠️ Проверьте WITH CHECK'
        WHEN qual IS NULL AND cmd = 'UPDATE' THEN '⚠️ Проверьте WITH CHECK'
        WHEN qual IS NULL AND cmd = 'DELETE' THEN '❌ ОПАСНО: можно удалять всё'
        WHEN qual::text LIKE '%auth.uid()%' THEN '✅ Безопасно: проверка пользователя'
        WHEN qual::text LIKE '%EXISTS%' THEN '✅ Безопасно: проверка через подзапрос'
        ELSE '⚠️ Проверьте вручную'
    END as security_status,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 100)
        ELSE 'NULL (проверьте WITH CHECK)'
    END as qual_preview
FROM pg_policies
WHERE tablename = 'equipment'
ORDER BY 
    CASE 
        WHEN qual::text = 'true' THEN 1
        WHEN qual IS NULL THEN 2
        ELSE 3
    END,
    cmd,
    policyname;

-- Проверяем безопасность всех политик для service_requests
SELECT 
    'service_requests' as table_name,
    policyname,
    cmd,
    roles,
    CASE 
        WHEN qual::text = 'true' THEN '❌ ОПАСНО: без ограничений'
        WHEN qual IS NULL AND cmd = 'SELECT' THEN '❌ ОПАСНО: видно всё'
        WHEN qual IS NULL AND cmd = 'INSERT' THEN '⚠️ Проверьте WITH CHECK'
        WHEN qual IS NULL AND cmd = 'UPDATE' THEN '⚠️ Проверьте WITH CHECK'
        WHEN qual IS NULL AND cmd = 'DELETE' THEN '❌ ОПАСНО: можно удалять всё'
        WHEN qual::text LIKE '%auth.uid()%' THEN '✅ Безопасно: проверка пользователя'
        WHEN qual::text LIKE '%EXISTS%' THEN '✅ Безопасно: проверка через подзапрос'
        ELSE '⚠️ Проверьте вручную'
    END as security_status,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 100)
        ELSE 'NULL (проверьте WITH CHECK)'
    END as qual_preview
FROM pg_policies
WHERE tablename = 'service_requests'
ORDER BY 
    CASE 
        WHEN qual::text = 'true' THEN 1
        WHEN qual IS NULL THEN 2
        ELSE 3
    END,
    cmd,
    policyname;

-- ============================================
-- ИТОГОВАЯ СВОДКА: Количество безопасных/опасных политик
-- ============================================

SELECT 
    tablename,
    COUNT(*) as total_policies,
    COUNT(CASE WHEN qual::text = 'true' OR (qual IS NULL AND cmd IN ('SELECT', 'DELETE')) THEN 1 END) as dangerous_policies,
    COUNT(CASE WHEN qual IS NOT NULL AND qual::text != 'true' THEN 1 END) as safe_policies,
    COUNT(CASE WHEN qual IS NULL AND cmd IN ('INSERT', 'UPDATE') THEN 1 END) as policies_with_check_only
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
GROUP BY tablename
ORDER BY tablename;

