-- Проверка WITH CHECK условий для политик INSERT и UPDATE
-- Важно: для INSERT и UPDATE политик qual может быть NULL, 
-- но тогда должны быть условия в with_check

SELECT 
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN qual IS NULL AND with_check IS NULL THEN '❌ ОПАСНО: нет условий ни в qual, ни в with_check'
        WHEN qual IS NULL AND with_check IS NOT NULL THEN '✅ Безопасно: условия в with_check'
        WHEN qual IS NOT NULL AND with_check IS NULL THEN '✅ Безопасно: условия в qual'
        WHEN qual IS NOT NULL AND with_check IS NOT NULL THEN '✅ Безопасно: условия в qual и with_check'
        ELSE '⚠️ Проверьте'
    END as security_status,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 100)
        ELSE 'NULL'
    END as qual_preview,
    CASE 
        WHEN with_check IS NOT NULL THEN substring(with_check::text, 1, 100)
        ELSE 'NULL'
    END as with_check_preview
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
AND cmd IN ('INSERT', 'UPDATE')
ORDER BY tablename, cmd, policyname;

-- Проверка: есть ли политики без условий вообще
SELECT 
    tablename,
    policyname,
    cmd,
    '❌ ОПАСНО: нет условий ни в qual, ни в with_check' as warning
FROM pg_policies
WHERE tablename IN ('equipment', 'service_requests')
AND qual IS NULL 
AND with_check IS NULL
ORDER BY tablename, policyname;

