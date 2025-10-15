-- Система назначения площадок менеджерам
-- Выполните этот скрипт в Supabase Dashboard

-- 1. Проверяем текущую структуру таблицы user_profiles
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Добавляем поле assigned_site_ids если его нет
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS assigned_site_ids TEXT[];

-- 3. Создаем таблицу для истории назначений площадок (опционально)
CREATE TABLE IF NOT EXISTS site_assignments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unassigned_at TIMESTAMP WITH TIME ZONE,
    unassigned_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, site_id, assigned_at)
);

-- 4. Создаем индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_site_assignments_user_id ON site_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_site_assignments_site_id ON site_assignments(site_id);
CREATE INDEX IF NOT EXISTS idx_site_assignments_active ON site_assignments(is_active);

-- 5. Проверяем текущих менеджеров площадок и их назначения
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.role,
    up.company_name,
    up.assigned_site_ids,
    COUNT(s.id) as assigned_sites_count
FROM user_profiles up
LEFT JOIN sites s ON s.id::TEXT = ANY(up.assigned_site_ids)
WHERE up.role = 'siteManager'
GROUP BY up.id, up.first_name, up.last_name, up.role, up.company_name, up.assigned_site_ids
ORDER BY up.first_name;

-- 6. Показываем все площадки для тестирования
-- Сначала проверим, какие типы данных у нас в таблицах
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('sites', 'companies') 
  AND column_name IN ('id', 'company_id')
ORDER BY table_name, column_name;

-- Теперь покажем площадки с правильным JOIN
SELECT 
    s.id,
    s.name,
    s.address,
    s.company_id,
    c.name as company_name,
    c.company_inn,
    c.id as company_uuid
FROM sites s
LEFT JOIN companies c ON (
    CASE 
        WHEN s.company_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
        THEN s.company_id::uuid = c.id
        ELSE s.company_id = c.company_inn::text
    END
)
ORDER BY c.name, s.name;
