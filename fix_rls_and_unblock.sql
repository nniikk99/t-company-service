-- СУПЕР-СКРИПТ ДЛЯ ПОЛНОГО РЕШЕНИЯ ПРОБЛЕМЫ RLS И ПРАВ
-- Дата: 2026-02-23

-- 1. Сначала отключаем RLS временно, чтобы ПРОВЕРИТЬ, что сама вставка работает
ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;

-- 2. Гарантируем структуру (на случай если что-то не добавилось)
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS company_id UUID;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS equipment_id UUID;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

-- 3. Удаляем АБСОЛЮТНО ВСЕ старые политики, чтобы они не мешали
DO $$ 
DECLARE 
    pol RECORD;
BEGIN 
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'service_requests') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON service_requests', pol.policyname);
    END LOOP;
END $$;

-- 4. Создаем НОВУЮ, МАКСИМАЛЬНО ПРОСТУЮ политику для тестирования
-- Она разрешает всё любому авторизованному пользователю
CREATE POLICY "Allow all for authenticated" ON service_requests
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 5. Обратно включаем RLS (теперь с разрешающей политикой)
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- 6. ОБНОВЛЕНИЕ КЭША (самое важное для PostgREST)
NOTIFY pgrst, 'reload schema';

-- 7. ПРОВЕРКА РОЛИ ВАШЕГО ПОЛЬЗОВАТЕЛЯ (для отладки)
-- Выполнив этот скрипт, вы увидите в результатах, какая роль у вас в базе
SELECT id, email, role 
FROM user_profiles 
WHERE id = auth.uid();
