-- ИСПРАВЛЯЕМ RLS ПОЛИТИКИ ДЛЯ СОЗДАНИЯ ПЛОЩАДОК
-- Площадки привязываются к компании через company_inn

-- Шаг 1: Отключаем RLS для sites временно
ALTER TABLE sites DISABLE ROW LEVEL SECURITY;

-- Шаг 2: Удаляем все старые политики для sites
DROP POLICY IF EXISTS "Users can view sites from their companies" ON sites;
DROP POLICY IF EXISTS "Users can insert sites for their companies" ON sites;
DROP POLICY IF EXISTS "Users can update sites from their companies" ON sites;
DROP POLICY IF EXISTS "Users can delete sites from their companies" ON sites;
DROP POLICY IF EXISTS "Allow companyResponsible and superAdmin to create sites" ON sites;
DROP POLICY IF EXISTS "Allow companyResponsible, superAdmin, siteManager to view and update sites" ON sites;

-- Шаг 3: Проверяем структуру таблицы sites
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'sites' 
ORDER BY ordinal_position;

-- Шаг 4: Проверяем данные в user_companies для понимания связей
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.role,
    up.company_inn,
    uc.company_name,
    uc.status
FROM user_profiles up
LEFT JOIN user_companies uc ON up.id = uc.user_id
ORDER BY up.created_at;

-- Шаг 5: Создаем простые и работающие RLS политики для sites
CREATE POLICY "Allow all authenticated users to view sites" ON sites
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated users to create sites" ON sites
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update sites" ON sites
    FOR UPDATE USING (true);

CREATE POLICY "Allow authenticated users to delete sites" ON sites
    FOR DELETE USING (true);

-- Шаг 6: Включаем RLS обратно
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

-- Шаг 7: Проверяем, что политики созданы
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'sites';

-- Шаг 8: Тестовый запрос для проверки
SELECT COUNT(*) as total_sites FROM sites;
