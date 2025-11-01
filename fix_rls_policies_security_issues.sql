-- Исправление проблем безопасности в RLS политиках
-- Дата: 2025-01-XX
-- Описание: Удаление опасных широких политик и исправление политик для equipment

-- ============================================
-- ШАГ 1: Удаление опасных широких политик
-- ============================================

-- Удаляем политику, позволяющую любому пользователю удалять оборудование
DROP POLICY IF EXISTS "Allow authenticated users to delete equipment" ON equipment;

-- Удаляем политику, позволяющую любому пользователю обновлять оборудование
DROP POLICY IF EXISTS "Allow authenticated users to update equipment" ON equipment;

-- Удаляем старые политики, которые могут конфликтовать с нашими
DROP POLICY IF EXISTS "Users can manage equipment of their companies" ON equipment;
DROP POLICY IF EXISTS "Users can view equipment of their companies" ON equipment;

-- ============================================
-- ШАГ 2: Исправление политики для обновления supplier_id
-- ============================================

-- Удаляем старую политику (если есть с таким именем)
DROP POLICY IF EXISTS "Поставщики могут обновлять supplier_id" ON equipment;

-- Создаем правильную политику с проверкой принадлежности оборудования
CREATE POLICY "Поставщики могут обновлять supplier_id только своего оборудования" ON equipment
  FOR UPDATE
  USING (
    -- Поставщик может обновлять только оборудование, где он уже является поставщиком
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
      AND equipment.supplier_id = auth.uid() -- ВАЖНО: проверяем принадлежность!
    )
  )
  WITH CHECK (
    -- При обновлении поставщик может устанавливать только свой ID
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'supplier'
      AND equipment.supplier_id = auth.uid() -- ВАЖНО: проверяем в WITH CHECK тоже!
    )
  );

-- ============================================
-- ШАГ 3: Добавление политики для создания оборудования компаниями
-- ============================================

-- Убедимся, что компании могут создавать оборудование
-- (политика "Компании могут управлять своим оборудованием" должна покрывать INSERT, но проверим)

-- Создаем отдельную политику для INSERT, если нужна более детальная логика
DROP POLICY IF EXISTS "Компании могут создавать оборудование" ON equipment;

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
-- ШАГ 4: Добавление политики для удаления (только администраторы)
-- ============================================

-- Создаем политику, позволяющую удалять оборудование только администраторам
DROP POLICY IF EXISTS "Только администраторы могут удалять оборудование" ON equipment;

CREATE POLICY "Только администраторы могут удалять оборудование" ON equipment
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- ============================================
-- ПРОВЕРКА: Просмотр текущих политик
-- ============================================

-- Проверяем политики для equipment после исправлений
SELECT 
    policyname,
    cmd,
    roles,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 100) || '...'
        ELSE 'NULL'
    END as qual_preview,
    CASE 
        WHEN with_check IS NOT NULL THEN substring(with_check::text, 1, 100) || '...'
        ELSE 'NULL'
    END as with_check_preview
FROM pg_policies
WHERE tablename = 'equipment'
ORDER BY policyname;

-- Проверяем политики для service_requests
SELECT 
    policyname,
    cmd,
    roles,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 100) || '...'
        ELSE 'NULL'
    END as qual_preview
FROM pg_policies
WHERE tablename = 'service_requests'
ORDER BY policyname;

