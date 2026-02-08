-- Скрипт для отключения RLS (Row Level Security) для таблицы sites
-- ПРИЧИНА: Приложение использует собственную систему авторизации (через таблицу user_profiles),
-- а не встроенную Auth Supabase. Из-за этого база данных "думает", что никто не залогинен (auth.uid() is null).
-- Поэтому любые RLS политики, проверяющие auth.uid(), будут блокировать доступ.

-- 1. Отключаем RLS для таблицы sites
ALTER TABLE sites DISABLE ROW LEVEL SECURITY;

-- 2. Проверяем статус (должно быть false)
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'sites';
