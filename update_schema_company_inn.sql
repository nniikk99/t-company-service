-- Обновление схемы базы данных для поддержки ИНН компаний
-- Добавляем поле company_inn в таблицы sites и equipment

-- Добавляем поле company_inn в таблицу sites
ALTER TABLE public.sites 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20);

-- Добавляем поле company_inn в таблицу equipment  
ALTER TABLE public.equipment 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20);

-- Добавляем поле company_inn в таблицу user_profiles (если еще нет)
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20);

-- Создаем индексы для быстрого поиска по ИНН
CREATE INDEX IF NOT EXISTS idx_sites_company_inn ON public.sites(company_inn);
CREATE INDEX IF NOT EXISTS idx_equipment_company_inn ON public.equipment(company_inn);
CREATE INDEX IF NOT EXISTS idx_user_profiles_company_inn ON public.user_profiles(company_inn);

-- Обновляем существующие записи (если нужно)
-- Для тестовых данных можно установить ИНН по умолчанию
-- UPDATE public.sites SET company_inn = '0000000001' WHERE company_inn IS NULL;
-- UPDATE public.equipment SET company_inn = '0000000001' WHERE company_inn IS NULL;

-- Проверяем структуру таблиц
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'sites' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'equipment' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND table_schema = 'public'
ORDER BY ordinal_position;
