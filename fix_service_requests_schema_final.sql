-- Скрипт для ПОЛНОГО исправления структуры и прав доступа таблицы service_requests
-- Дата: 2026-02-23

DO $$ 
BEGIN 
    -- 1. Убеждаемся, что таблица существует
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'service_requests') THEN
        CREATE TABLE service_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
        );
    END IF;

    -- 2. Добавляем ВСЕ необходимые колонки, если их нет
    -- Мы добавляем их по одной, чтобы не вызвать ошибку если колонка уже есть
    
    PERFORM add_column_if_missing('service_requests', 'description', 'TEXT');
    PERFORM add_column_if_missing('service_requests', 'title', 'TEXT');
    PERFORM add_column_if_missing('service_requests', 'status', 'TEXT DEFAULT ''pending''');
    PERFORM add_column_if_missing('service_requests', 'priority', 'TEXT DEFAULT ''normal''');
    PERFORM add_column_if_missing('service_requests', 'type', 'TEXT');
    PERFORM add_column_if_missing('service_requests', 'user_id', 'UUID REFERENCES auth.users(id)');
    PERFORM add_column_if_missing('service_requests', 'company_id', 'UUID');
    PERFORM add_column_if_missing('service_requests', 'equipment_id', 'UUID');
    PERFORM add_column_if_missing('service_requests', 'supplier_id', 'UUID');
    PERFORM add_column_if_missing('service_requests', 'attachments', 'TEXT[]');
    PERFORM add_column_if_missing('service_requests', 'estimated_cost', 'NUMERIC(10,2)');
    PERFORM add_column_if_missing('service_requests', 'scheduled_at', 'TIMESTAMP WITH TIME ZONE');
    PERFORM add_column_if_missing('service_requests', 'notes', 'TEXT');

END $$;

-- 3. Исправляем RLS (Права доступа)
-- Включаем RLS, но добавляем политику для супер-админов
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Удаляем старую ограничивающую политику на вставку
DROP POLICY IF EXISTS "Создатели могут создавать заявки" ON service_requests;
DROP POLICY IF EXISTS "Админы и создатели могут создавать заявки" ON service_requests;

-- Создаем новую расширенную политику на вставку
CREATE POLICY "Админы и создатели могут создавать заявки" ON service_requests
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator', 'operatorPM', 'siteManager', 'companyResponsible')
    )
  );

-- Политика на просмотр (убеждаемся что админы видят всё)
DROP POLICY IF EXISTS "Администраторы видят все заявки" ON service_requests;
CREATE POLICY "Администраторы видят все заявки" ON service_requests
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- 4. Принудительное обновление кэша PostgREST
NOTIFY pgrst, 'reload schema';

-- Функция-помощник (если её нет)
CREATE OR REPLACE FUNCTION add_column_if_missing(t_name TEXT, c_name TEXT, c_type TEXT) 
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = t_name AND column_name = c_name) THEN
    EXECUTE 'ALTER TABLE ' || t_name || ' ADD COLUMN ' || c_name || ' ' || c_type;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 5. Проверочный запрос
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'service_requests';
