-- Исправление политики "Администраторы видят все оборудование"
-- Проблема: Политика не включает superAdmin для чтения всех записей

-- Проверяем текущую политику
SELECT 
    'Текущая политика' as info,
    policyname,
    cmd,
    qual::text as using_condition,
    with_check::text as with_check_condition
FROM pg_policies
WHERE tablename = 'equipment'
AND policyname LIKE '%Администраторы%';

-- Удаляем старую политику, если она не включает superAdmin
DROP POLICY IF EXISTS "Администраторы видят все оборудование" ON equipment;

-- Создаем правильную политику для чтения всех записей администраторами
CREATE POLICY "Администраторы видят все оборудование" ON equipment
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- Проверяем политики после исправления
SELECT 
    'Политики после исправления' as info,
    policyname,
    cmd,
    CASE 
        WHEN qual::text LIKE '%superAdmin%' OR qual::text LIKE '%administrator%' THEN '✅ Включает superAdmin'
        ELSE '❌ Нет superAdmin'
    END as status
FROM pg_policies
WHERE tablename = 'equipment'
AND policyname LIKE '%Администраторы%';

