-- Проверка доступа пользователя к площадкам
-- Используется для диагностики проблем с созданием/просмотром площадок
-- Дата: 2025-01-XX

-- ============================================
-- ШАГ 1: Найти пользователя по телефону
-- ============================================

-- Замените '+79817467395' на нужный телефон
SELECT 
    id,
    first_name,
    last_name,
    phone,
    email,
    role,
    company_id,
    company_inn
FROM user_profiles
WHERE phone = '+79817467395'
   OR phone LIKE '%9817467395%'
   OR phone LIKE '%79817467395%';

-- ============================================
-- ШАГ 2: Проверить данные пользователя
-- ============================================

-- После того как нашли user_id, замените 'USER_ID_HERE' на реальный ID
-- И выполните этот запрос:

/*
SELECT 
    up.id as user_id,
    up.first_name,
    up.last_name,
    up.phone,
    up.role,
    up.company_id as user_company_id,
    up.company_inn as user_company_inn,
    c.id as company_id_from_companies,
    c.name as company_name,
    c.inn as company_inn_from_companies
FROM user_profiles up
LEFT JOIN companies c ON c.id = up.company_id OR c.inn = up.company_inn
WHERE up.id = 'USER_ID_HERE';
*/

-- ============================================
-- ШАГ 3: Проверить существующие площадки
-- ============================================

-- Показываем все площадки в базе
SELECT 
    id,
    company_id,
    company_inn,
    name,
    address,
    created_at
FROM sites
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- ШАГ 4: Проверить RLS политики для текущего пользователя
-- ============================================

-- Этот запрос нужно выполнить от имени пользователя (через приложение)
-- или использовать auth.uid() в Supabase SQL Editor

/*
-- Проверка SELECT политики
SELECT 
    s.*,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('superAdmin', 'administrator')
        ) THEN '✅ Доступ (администратор)'
        WHEN EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('companyResponsible', 'siteManager', 'operatorPM')
            AND (
                s.company_id = up.company_id
                OR (s.company_inn IS NOT NULL AND s.company_inn = up.company_inn)
            )
        ) THEN '✅ Доступ (пользователь компании)'
        ELSE '❌ Нет доступа'
    END as access_status
FROM sites s;
*/

-- ============================================
-- ШАГ 5: Тестовая вставка (для проверки INSERT политики)
-- ============================================

-- ВНИМАНИЕ: Этот запрос нужно выполнить от имени пользователя через приложение
-- или использовать auth.uid() в Supabase SQL Editor

/*
-- Проверка, может ли пользователь создать площадку
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('superAdmin', 'administrator')
        ) THEN '✅ Может создать (администратор)'
        WHEN EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('companyResponsible', 'siteManager')
            AND up.company_id IS NOT NULL
        ) THEN '✅ Может создать (пользователь с company_id)'
        WHEN EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('companyResponsible', 'siteManager')
            AND up.company_inn IS NOT NULL
        ) THEN '✅ Может создать (пользователь с company_inn)'
        ELSE '❌ Не может создать (нет прав или company_id/company_inn)'
    END as insert_permission,
    up.role,
    up.company_id,
    up.company_inn
FROM user_profiles up
WHERE up.id = auth.uid();
*/

-- ============================================
-- ШАГ 6: Проверка структуры таблицы sites
-- ============================================

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'sites'
ORDER BY ordinal_position;

