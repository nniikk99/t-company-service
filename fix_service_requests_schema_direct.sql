-- ФИНАЛЬНЫЙ СКРИПТ ИСПРАВЛЕНИЯ ТАБЛИЦЫ ЗАЯВОК (Service Requests)
-- Этот скрипт гарантирует наличие колонок и правильные права для всех ролей, включая SuperAdmin

-- 1. Добавляем колонки напрямую (PostgreSQL поддерживает IF NOT EXISTS для колонок)
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal';
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS type TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS company_id UUID;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS equipment_id UUID;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS supplier_id UUID;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS attachments TEXT[];
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS estimated_cost NUMERIC(10,2);
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS notes TEXT;

-- 2. Включаем RLS
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- 3. Настройка прав доступа (RLS Policies)

-- Удаляем старые конфликтующие политики
DROP POLICY IF EXISTS "Создатели могут создавать заявки" ON service_requests;
DROP POLICY IF EXISTS "Админы и создатели могут создавать заявки" ON service_requests;
DROP POLICY IF EXISTS "Администраторы видят все заявки" ON service_requests;
DROP POLICY IF EXISTS "Поставщики видят свои заявки" ON service_requests;
DROP POLICY IF EXISTS "Создатели видят свои заявки" ON service_requests;
DROP POLICY IF EXISTS "Инженеры видят назначенные заявки" ON service_requests;

-- Политика: КТО МОЖЕТ ВСТАВЛЯТЬ (INSERT) - Создатель или Админ
CREATE POLICY "Allow matching insert" ON service_requests
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- Политика: КТО МОЖЕТ ВИДЕТЬ (SELECT) - Админ видит всё, остальные своё
CREATE POLICY "Allow selective view" ON service_requests
  FOR SELECT
  USING (
    auth.uid() = user_id OR -- Тот кто создал
    auth.uid() = supplier_id OR -- Поставщик
    -- Админы
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- Политика: КТО МОЖЕТ ОБНОВЛЯТЬ (UPDATE)
CREATE POLICY "Allow selective update" ON service_requests
  FOR UPDATE
  USING (
    auth.uid() = user_id OR
    auth.uid() = supplier_id OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- 4. ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ КЭША SCHEМА
-- Это критически важно для исправления ошибки PGRST204
NOTIFY pgrst, 'reload schema';

-- 5. Проверка (результат появится в таблице снизу в Supabase)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'service_requests';
