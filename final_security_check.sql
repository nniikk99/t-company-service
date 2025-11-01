-- ФИНАЛЬНАЯ ПРОВЕРКА БЕЗОПАСНОСТИ RLS ПОЛИТИК
-- Проверяем, есть ли политики БЕЗ условий вообще

-- ============================================
-- ПРОВЕРКА 1: Политики полностью без условий (ОПАСНО!)
-- ============================================

SELECT 
    '❌ ОПАСНЫЕ ПОЛИТИКИ БЕЗ УСЛОВИЙ' as check_type,
    tablename,
    policyname,
    cmd,
    roles,
    'Эта политика не имеет условий ни в qual, ни в with_check!' as warning
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
AND qual IS NULL 
AND with_check IS NULL
ORDER BY tablename, cmd, policyname;

-- Если этот запрос вернул 0 строк - ОТЛИЧНО! ✅
-- Если вернул строки - нужно исправить эти политики ❌

-- ============================================
-- ПРОВЕРКА 2: Политики с qual = 'true' (ОПАСНО!)
-- ============================================

SELECT 
    '❌ ОПАСНЫЕ ПОЛИТИКИ С qual = true' as check_type,
    tablename,
    policyname,
    cmd,
    roles,
    'Эта политика разрешает доступ всем без проверок!' as warning
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
AND qual::text = 'true'
ORDER BY tablename, cmd, policyname;

-- Если этот запрос вернул 0 строк - ОТЛИЧНО! ✅

-- ============================================
-- ПРОВЕРКА 3: Сводка по безопасности всех политик
-- ============================================

SELECT 
    tablename,
    cmd,
    COUNT(*) as total_count,
    COUNT(CASE WHEN qual::text = 'true' THEN 1 END) as dangerous_qual_true,
    COUNT(CASE WHEN qual IS NULL AND with_check IS NULL THEN 1 END) as dangerous_no_conditions,
    COUNT(CASE WHEN qual IS NOT NULL AND qual::text != 'true' THEN 1 END) as safe_with_qual,
    COUNT(CASE WHEN qual IS NULL AND with_check IS NOT NULL THEN 1 END) as safe_with_check_only,
    COUNT(CASE WHEN qual IS NOT NULL AND with_check IS NOT NULL THEN 1 END) as safe_with_both
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
GROUP BY tablename, cmd
ORDER BY tablename, cmd;

-- ============================================
-- ПРОВЕРКА 4: Все политики с их статусом безопасности
-- ============================================

SELECT 
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN qual::text = 'true' THEN '❌ ОПАСНО: qual = true'
        WHEN qual IS NULL AND with_check IS NULL THEN '❌ ОПАСНО: нет условий'
        WHEN qual IS NULL AND cmd = 'SELECT' THEN '❌ ОПАСНО: SELECT без условий'
        WHEN qual IS NULL AND cmd = 'DELETE' THEN '❌ ОПАСНО: DELETE без условий'
        WHEN qual IS NULL AND cmd IN ('INSERT', 'UPDATE') AND with_check IS NOT NULL THEN '✅ Безопасно: условия в with_check'
        WHEN qual IS NOT NULL AND qual::text != 'true' AND with_check IS NULL THEN '✅ Безопасно: условия в qual'
        WHEN qual IS NOT NULL AND qual::text != 'true' AND with_check IS NOT NULL THEN '✅ Безопасно: условия в qual и with_check'
        ELSE '⚠️ Проверьте вручную'
    END as final_security_status
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
ORDER BY 
    CASE 
        WHEN qual::text = 'true' THEN 1
        WHEN qual IS NULL AND with_check IS NULL THEN 2
        WHEN qual IS NULL AND cmd IN ('SELECT', 'DELETE') THEN 3
        ELSE 4
    END,
    tablename,
    cmd,
    policyname;

-- ============================================
-- ИТОГОВЫЙ ВЕРДИКТ
-- ============================================

SELECT 
    CASE 
        WHEN COUNT(CASE WHEN qual::text = 'true' OR (qual IS NULL AND with_check IS NULL AND cmd IN ('SELECT', 'DELETE')) THEN 1 END) = 0 
        THEN '✅ ОТЛИЧНО! Все политики безопасны!'
        ELSE '❌ ВНИМАНИЕ! Есть опасные политики!'
    END as final_verdict,
    COUNT(*) as total_policies,
    COUNT(CASE WHEN qual::text = 'true' THEN 1 END) as dangerous_qual_true,
    COUNT(CASE WHEN qual IS NULL AND with_check IS NULL THEN 1 END) as dangerous_no_conditions
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests');

