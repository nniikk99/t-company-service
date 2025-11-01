-- Проверка безопасности RLS политик
-- Выполните этот скрипт для проверки потенциальных проблем безопасности

-- ============================================
-- ПРОВЕРКА 1: Опасные широкие политики для equipment
-- ============================================

SELECT 
    'ОПАСНО: Широкие политики для equipment' as check_type,
    policyname,
    cmd,
    qual,
    'Любой аутентифицированный пользователь может выполнять эту операцию!' as warning
FROM pg_policies
WHERE tablename = 'equipment'
AND (
    -- Политики с qual = 'true' или без условий - очень опасны!
    qual::text = 'true'
    OR qual IS NULL
    OR policyname LIKE '%Allow authenticated%'
    OR policyname LIKE '%Allow all%'
)
ORDER BY policyname;

-- ============================================
-- ПРОВЕРКА 2: Опасные широкие политики для service_requests
-- ============================================

SELECT 
    'ОПАСНО: Широкие политики для service_requests' as check_type,
    policyname,
    cmd,
    qual,
    'Любой аутентифицированный пользователь может выполнять эту операцию!' as warning
FROM pg_policies
WHERE tablename = 'service_requests'
AND (
    qual::text = 'true'
    OR qual IS NULL
    OR policyname LIKE '%Allow authenticated%'
    OR policyname LIKE '%Allow all%'
)
ORDER BY policyname;

-- ============================================
-- ПРОВЕРКА 3: Политики DELETE для equipment (должны быть только у админов)
-- ============================================

SELECT 
    'Проверка DELETE политик для equipment' as check_type,
    policyname,
    cmd,
    qual,
    CASE 
        WHEN qual::text LIKE '%superAdmin%' OR qual::text LIKE '%administrator%' 
        THEN '✅ Безопасно: только для администраторов'
        WHEN qual::text = 'true' OR qual IS NULL
        THEN '❌ ОПАСНО: позволяет удалять всем!'
        ELSE '⚠️ Проверьте вручную'
    END as security_status
FROM pg_policies
WHERE tablename = 'equipment'
AND cmd = 'DELETE'
ORDER BY policyname;

-- ============================================
-- ПРОВЕРКА 4: Политики UPDATE для equipment
-- ============================================

SELECT 
    'Проверка UPDATE политик для equipment' as check_type,
    policyname,
    cmd,
    CASE 
        WHEN qual::text LIKE '%auth.uid()%' AND qual::text LIKE '%supplier_id%'
        THEN '✅ Проверяет принадлежность'
        WHEN qual::text LIKE '%auth.uid()%' AND qual::text LIKE '%company_id%'
        THEN '✅ Проверяет принадлежность компании'
        WHEN qual::text LIKE '%superAdmin%' OR qual::text LIKE '%administrator%'
        THEN '✅ Только администраторы'
        WHEN qual::text = 'true' OR qual IS NULL
        THEN '❌ ОПАСНО: без проверок!'
        ELSE '⚠️ Проверьте вручную'
    END as security_status,
    substring(qual::text, 1, 150) as qual_preview
FROM pg_policies
WHERE tablename = 'equipment'
AND cmd = 'UPDATE'
ORDER BY policyname;

-- ============================================
-- ПРОВЕРКА 5: Сводка всех политик
-- ============================================

SELECT 
    tablename,
    COUNT(*) as total_policies,
    COUNT(CASE WHEN cmd = 'SELECT' THEN 1 END) as select_policies,
    COUNT(CASE WHEN cmd = 'INSERT' THEN 1 END) as insert_policies,
    COUNT(CASE WHEN cmd = 'UPDATE' THEN 1 END) as update_policies,
    COUNT(CASE WHEN cmd = 'DELETE' THEN 1 END) as delete_policies,
    COUNT(CASE WHEN cmd = 'ALL' THEN 1 END) as all_policies
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
GROUP BY tablename
ORDER BY tablename;

-- ============================================
-- ПРОВЕРКА 6: Все политики с их условиями (полный список)
-- ============================================

SELECT 
    tablename,
    policyname,
    cmd,
    roles,
    CASE 
        WHEN qual::text = 'true' THEN '❌ ОПАСНО: без ограничений'
        WHEN qual IS NULL THEN '⚠️ Нет условий'
        WHEN qual::text LIKE '%auth.uid()%' THEN '✅ Использует проверку пользователя'
        ELSE '⚠️ Проверьте'
    END as qual_status,
    substring(qual::text, 1, 200) as qual_preview
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
ORDER BY tablename, cmd, policyname;

