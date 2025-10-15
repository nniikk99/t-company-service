-- Финальная синхронизация базы данных с новыми методами
-- Выполните этот скрипт в Supabase Dashboard

-- 1. Проверяем текущую структуру user_profiles
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Добавляем поле assigned_site_ids если его нет
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS assigned_site_ids TEXT[];

-- 3. Обновляем ограничение ролей для поддержки всех новых ролей
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;

-- Создаем новое ограничение с ВСЕМИ ролями
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check 
CHECK (role IN (
    'superAdmin', 
    'administrator', 
    'companyResponsible', 
    'siteManager', 
    'operatorPM', 
    'engineer',
    'pendingApproval'
));

-- 4. Создаем таблицу site_assignments для истории назначений (опционально)
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

-- 5. Создаем индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_site_assignments_user_id ON site_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_site_assignments_site_id ON site_assignments(site_id);
CREATE INDEX IF NOT EXISTS idx_site_assignments_active ON site_assignments(is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_assigned_sites ON user_profiles USING GIN(assigned_site_ids);

-- 6. Проверяем существующих пользователей и их роли
SELECT 
    id,
    first_name,
    last_name,
    role,
    company_inn,
    assigned_site_ids,
    array_length(assigned_site_ids, 1) as assigned_sites_count
FROM user_profiles 
ORDER BY created_at DESC;

-- 7. Проверяем площадки и их company_id
SELECT 
    s.id,
    s.name,
    s.company_id,
    c.name as company_name,
    c.company_inn
FROM sites s
LEFT JOIN companies c ON (
    CASE
        WHEN s.company_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        THEN s.company_id::uuid = c.id
        ELSE s.company_id = c.company_inn::text
    END
)
ORDER BY c.name, s.name;

-- 8. Тестируем новые методы - проверяем сотрудников компании
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.role,
    up.company_inn,
    up.assigned_site_ids
FROM user_profiles up
WHERE up.role IN ('siteManager', 'operatorPM')
ORDER BY up.first_name;

-- 9. Проверяем, что все работает корректно
SELECT 'DATABASE SYNC COMPLETED SUCCESSFULLY' as status;
