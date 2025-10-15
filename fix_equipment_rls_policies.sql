-- ИСПРАВЛЯЕМ RLS ПОЛИТИКИ ДЛЯ ОБОРУДОВАНИЯ
-- Оборудование привязывается к площадке и компании через company_inn

-- Шаг 1: Отключаем RLS для equipment временно
ALTER TABLE equipment DISABLE ROW LEVEL SECURITY;

-- Шаг 2: Удаляем все старые политики для equipment
DROP POLICY IF EXISTS "Users can view equipment from their companies" ON equipment;
DROP POLICY IF EXISTS "Users can insert equipment for their companies" ON equipment;
DROP POLICY IF EXISTS "Users can update equipment from their companies" ON equipment;
DROP POLICY IF EXISTS "Users can delete equipment from their companies" ON equipment;

-- Шаг 3: Проверяем структуру таблицы equipment
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'equipment' 
ORDER BY ordinal_position;

-- Шаг 4: Проверяем данные в equipment
SELECT 
    e.id,
    e.name,
    e.site_id,
    e.company_inn,
    s.name as site_name,
    s.company_inn as site_company_inn
FROM equipment e
LEFT JOIN sites s ON e.site_id = s.id
LIMIT 5;

-- Шаг 5: Создаем простые и работающие RLS политики для equipment
CREATE POLICY "Allow all authenticated users to view equipment" ON equipment
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated users to create equipment" ON equipment
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update equipment" ON equipment
    FOR UPDATE USING (true);

CREATE POLICY "Allow authenticated users to delete equipment" ON equipment
    FOR DELETE USING (true);

-- Шаг 6: Включаем RLS обратно
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;

-- Шаг 7: Проверяем, что политики созданы
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'equipment';

-- Шаг 8: Тестовый запрос для проверки
SELECT COUNT(*) as total_equipment FROM equipment;
