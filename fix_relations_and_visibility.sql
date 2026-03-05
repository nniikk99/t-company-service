-- 1. ПОЛНАЯ ЗАЧИСТКА ПЕРЕД ВОССТАНОВЛЕНИЕМ
-- Очищаем таблицу от заявок, которые ссылаются на несуществующее оборудование или пользователей,
-- так как это мешает созданию Foreign Keys (внешних ключей).
DELETE FROM service_requests 
WHERE (equipment_id IS NOT NULL AND equipment_id::TEXT NOT IN (SELECT id::TEXT FROM equipment))
   OR (user_id::TEXT NOT IN (SELECT id::TEXT FROM user_profiles));

-- 2. ВОЗВРАЩАЕМ ТИПЫ UUID (необходимо для работы автоматических Join-ов в Supabase)
-- Это исправляет ошибку PGRST200
ALTER TABLE service_requests ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE service_requests ALTER COLUMN equipment_id TYPE UUID USING equipment_id::UUID;
ALTER TABLE service_requests ALTER COLUMN company_id TYPE UUID USING company_id::UUID;

-- 3. ВОССТАНАВЛИВАЕМ ВНЕШНИЕ КЛЮЧИ (СВЯЗИ)
-- Без этого Supabase не может делать .select('*, equipment(*)')
ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_equipment_id_fkey 
FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE CASCADE;

ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE SET NULL;

-- 4. ВКЛЮЧАЕМ RLS И НАСТРАИВАЕМ ВИДИМОСТЬ (Чтобы не видеть чужие заявки "Леман Про" и т.д.)
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Удаляем старые политики
DROP POLICY IF EXISTS "allow_all" ON service_requests;
DROP POLICY IF EXISTS "user_select_own" ON service_requests;

-- ПРАВИЛО: Видим только свои заявки или заявки своей компании по ИНН
CREATE POLICY "service_requests_visibility" ON service_requests
FOR SELECT TO authenticated
USING (
    user_id = auth.uid() 
    OR 
    (company_inn IS NOT NULL AND company_inn = (SELECT company_inn FROM user_profiles WHERE id = auth.uid()))
    OR
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator'))
);

-- ПРАВИЛО: Создавать может любой авторизованный пользователь для СЕБЯ
CREATE POLICY "service_requests_insert" ON service_requests
FOR INSERT TO authenticated
WITH CHECK (true);

-- 5. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
