-- Отключаем RLS для таблицы equipment, так как авторизация происходит
-- через кастомный механизм, и auth.uid() возвращает NULL
ALTER TABLE equipment DISABLE ROW LEVEL SECURITY;
