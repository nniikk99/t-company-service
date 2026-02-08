-- Комплексное отключение RLS для таблицы equipment
-- Выполните весь этот скрипт целиком в Supabase SQL Editor

-- Шаг 1: Удаляем все существующие политики RLS для equipment
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON equipment;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON equipment;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON equipment;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON equipment;
DROP POLICY IF EXISTS "Allow users to view equipment" ON equipment;
DROP POLICY IF EXISTS "Allow users to insert equipment" ON equipment;
DROP POLICY IF EXISTS "Allow users to update equipment" ON equipment;
DROP POLICY IF EXISTS "Allow users to delete equipment" ON equipment;
DROP POLICY IF EXISTS "Users can view equipment from their company" ON equipment;
DROP POLICY IF EXISTS "Users can insert equipment for their company" ON equipment;
DROP POLICY IF EXISTS "Users can update equipment from their company" ON equipment;
DROP POLICY IF EXISTS "Users can delete equipment from their company" ON equipment;
DROP POLICY IF EXISTS "Admin can view all equipment" ON equipment;
DROP POLICY IF EXISTS "Admin can insert equipment" ON equipment;
DROP POLICY IF EXISTS "Admin can update all equipment" ON equipment;
DROP POLICY IF EXISTS "Admin can delete all equipment" ON equipment;

-- Шаг 2: Отключаем RLS для таблицы equipment
ALTER TABLE equipment DISABLE ROW LEVEL SECURITY;

-- Проверка: показываем текущий статус RLS
SELECT 
    tablename, 
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'equipment';
