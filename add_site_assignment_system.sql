-- Система назначения площадок менеджерам
-- Добавляем необходимые поля и функции для управления назначениями

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

-- 5. Создаем функцию для назначения площадки менеджеру
CREATE OR REPLACE FUNCTION assign_site_to_manager(
    p_user_id UUID,
    p_site_id UUID,
    p_assigned_by UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_role VARCHAR(50);
    v_site_company_id UUID;
    v_user_company_id UUID;
    v_existing_sites TEXT[];
BEGIN
    -- Проверяем, что пользователь существует и является менеджером площадки
    SELECT role INTO v_user_role 
    FROM user_profiles 
    WHERE id = p_user_id;
    
    IF v_user_role != 'siteManager' THEN
        RAISE EXCEPTION 'Пользователь должен иметь роль siteManager';
    END IF;
    
    -- Проверяем, что площадка существует
    SELECT company_id INTO v_site_company_id 
    FROM sites 
    WHERE id = p_site_id;
    
    IF v_site_company_id IS NULL THEN
        RAISE EXCEPTION 'Площадка не найдена';
    END IF;
    
    -- Проверяем, что пользователь принадлежит к той же компании
    SELECT company_id INTO v_user_company_id 
    FROM user_profiles 
    WHERE id = p_user_id;
    
    IF v_user_company_id != v_site_company_id THEN
        RAISE EXCEPTION 'Пользователь и площадка должны принадлежать одной компании';
    END IF;
    
    -- Получаем текущие назначенные площадки
    SELECT assigned_site_ids INTO v_existing_sites 
    FROM user_profiles 
    WHERE id = p_user_id;
    
    -- Добавляем новую площадку к списку
    IF v_existing_sites IS NULL THEN
        v_existing_sites := ARRAY[p_site_id::TEXT];
    ELSE
        v_existing_sites := v_existing_sites || p_site_id::TEXT;
    END IF;
    
    -- Обновляем назначенные площадки
    UPDATE user_profiles 
    SET assigned_site_ids = v_existing_sites,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Добавляем запись в историю назначений
    INSERT INTO site_assignments (user_id, site_id, assigned_by)
    VALUES (p_user_id, p_site_id, p_assigned_by);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 6. Создаем функцию для отмены назначения площадки
CREATE OR REPLACE FUNCTION unassign_site_from_manager(
    p_user_id UUID,
    p_site_id UUID,
    p_unassigned_by UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_existing_sites TEXT[];
BEGIN
    -- Получаем текущие назначенные площадки
    SELECT assigned_site_ids INTO v_existing_sites 
    FROM user_profiles 
    WHERE id = p_user_id;
    
    IF v_existing_sites IS NULL OR NOT (p_site_id::TEXT = ANY(v_existing_sites)) THEN
        RAISE EXCEPTION 'Площадка не назначена данному пользователю';
    END IF;
    
    -- Удаляем площадку из списка
    v_existing_sites := array_remove(v_existing_sites, p_site_id::TEXT);
    
    -- Обновляем назначенные площадки
    UPDATE user_profiles 
    SET assigned_site_ids = v_existing_sites,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Обновляем запись в истории назначений
    UPDATE site_assignments 
    SET is_active = false,
        unassigned_at = NOW(),
        unassigned_by = p_unassigned_by,
        updated_at = NOW()
    WHERE user_id = p_user_id 
      AND site_id = p_site_id 
      AND is_active = true;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 7. Создаем функцию для получения площадок менеджера
CREATE OR REPLACE FUNCTION get_manager_sites(p_user_id UUID)
RETURNS TABLE (
    site_id UUID,
    site_name VARCHAR(255),
    site_address TEXT,
    company_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id as site_id,
        s.name as site_name,
        s.address as site_address,
        c.name as company_name
    FROM sites s
    JOIN companies c ON s.company_id = c.id
    JOIN user_profiles up ON up.id = p_user_id
    WHERE s.id::TEXT = ANY(up.assigned_site_ids)
    ORDER BY s.name;
END;
$$ LANGUAGE plpgsql;

-- 8. Создаем функцию для получения доступных площадок для назначения
CREATE OR REPLACE FUNCTION get_available_sites_for_assignment(p_user_id UUID)
RETURNS TABLE (
    site_id UUID,
    site_name VARCHAR(255),
    site_address TEXT,
    company_name VARCHAR(255),
    is_assigned BOOLEAN
) AS $$
DECLARE
    v_user_company_id UUID;
BEGIN
    -- Получаем компанию пользователя
    SELECT company_id INTO v_user_company_id 
    FROM user_profiles 
    WHERE id = p_user_id;
    
    RETURN QUERY
    SELECT 
        s.id as site_id,
        s.name as site_name,
        s.address as site_address,
        c.name as company_name,
        CASE 
            WHEN s.id::TEXT = ANY(up.assigned_site_ids) THEN true
            ELSE false
        END as is_assigned
    FROM sites s
    JOIN companies c ON s.company_id = c.id
    JOIN user_profiles up ON up.id = p_user_id
    WHERE s.company_id = v_user_company_id
    ORDER BY s.name;
END;
$$ LANGUAGE plpgsql;

-- 9. Проверяем текущих менеджеров площадок и их назначения
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

-- 10. Показываем все площадки для тестирования
SELECT 
    s.id,
    s.name,
    s.address,
    c.name as company_name,
    c.company_inn
FROM sites s
JOIN companies c ON s.company_id = c.id
ORDER BY c.name, s.name;
