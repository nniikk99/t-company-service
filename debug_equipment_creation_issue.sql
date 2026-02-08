-- Отладка проблемы создания оборудования для companyResponsible
-- Проверяем, почему RLS блокирует создание оборудования

-- ШАГ 1: Проверяем текущего пользователя (выполните от имени ответственного лица)
SELECT 
    id,
    email,
    first_name,
    last_name,
    role,
    company_id,
    company_inn,
    position,
    is_active
FROM user_profiles
WHERE id = auth.uid();
-- Убедитесь, что role = 'companyResponsible' и company_id заполнен

-- ШАГ 2: Проверяем политики INSERT для equipment
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 200)
        ELSE 'NULL'
    END as qual_text,
    CASE 
        WHEN with_check IS NOT NULL THEN with_check::text
        ELSE 'NULL'
    END as with_check_full_text
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL')
ORDER BY cmd, policyname;

-- ШАГ 3: Тестируем условие политики вручную
-- Эмулируем проверку WITH CHECK для роли companyResponsible
-- ЗАМЕНИТЕ 'YOUR_COMPANY_ID' на реальный company_id из Шага 1
SELECT 
    'Проверка прав на создание оборудования' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('companyResponsible', 'siteManager', 'operatorPM', 'superAdmin', 'administrator')
            AND (
                -- Тестируем с вашим company_id
                'YOUR_COMPANY_ID' = user_profiles.company_id
                OR 
                'YOUR_COMPANY_INN' = user_profiles.company_inn
                OR
                user_profiles.role IN ('superAdmin', 'administrator')
            )
        )
        THEN '✅ Политика должна разрешать создание'
        ELSE '❌ Политика блокирует создание'
    END as result;

-- ШАГ 4: Проверяем, есть ли вообще политики INSERT
SELECT 
    COUNT(*) as insert_policies_count,
    COUNT(CASE WHEN cmd = 'ALL' THEN 1 END) as all_policies_count,
    CASE 
        WHEN COUNT(*) = 0 AND COUNT(CASE WHEN cmd = 'ALL' THEN 1 END) = 0
        THEN '❌ НЕТ политик, разрешающих INSERT'
        WHEN COUNT(*) > 0 OR COUNT(CASE WHEN cmd = 'ALL' THEN 1 END) > 0
        THEN '✅ Есть политики для INSERT'
        ELSE '⚠️ Проверьте'
    END as status
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL');

-- ШАГ 5: Проверяем, включен ли RLS для таблицы equipment
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity = true THEN '✅ RLS включен'
        ELSE '❌ RLS выключен'
    END as status
FROM pg_tables
WHERE tablename = 'equipment';

-- ШАГ 6: Смотрим полный текст политики WITH CHECK
SELECT 
    policyname,
    pg_get_expr(polwithcheck, polrelid) as with_check_full_text
FROM pg_policy pol
JOIN pg_class cls ON pol.polrelid = cls.oid
WHERE cls.relname = 'equipment'
AND (polcmd = 'r' OR polcmd = '*'); -- 'r' = INSERT, '*' = ALL

