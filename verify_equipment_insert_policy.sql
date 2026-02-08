-- Проверка политик INSERT для equipment
-- Убеждаемся, что operatorPM может создавать оборудование

-- Проверяем детали политики INSERT
SELECT 
    policyname,
    cmd,
    roles,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 200)
        ELSE 'NULL'
    END as qual_preview,
    CASE 
        WHEN with_check IS NOT NULL THEN substring(with_check::text, 1, 200)
        ELSE 'NULL'
    END as with_check_preview,
    CASE 
        WHEN with_check::text LIKE '%operatorPM%' THEN '✅ Включает operatorPM'
        WHEN with_check::text LIKE '%siteManager%' AND with_check::text LIKE '%companyResponsible%' THEN '⚠️ Проверьте: возможно нет operatorPM'
        WHEN with_check IS NULL THEN '❌ Нет условий'
        ELSE '⚠️ Проверьте вручную'
    END as operatorPM_status
FROM pg_policies
WHERE tablename = 'equipment'
AND cmd = 'INSERT'
ORDER BY policyname;

-- Проверяем политику ALL (которая тоже должна покрывать INSERT)
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN qual IS NOT NULL THEN substring(qual::text, 1, 200)
        ELSE 'NULL'
    END as qual_preview,
    CASE 
        WHEN with_check IS NOT NULL THEN substring(with_check::text, 1, 200)
        ELSE 'NULL'
    END as with_check_preview,
    CASE 
        WHEN (qual::text LIKE '%operatorPM%' OR with_check::text LIKE '%operatorPM%') THEN '✅ Включает operatorPM'
        WHEN (qual::text LIKE '%siteManager%' OR with_check::text LIKE '%siteManager%') THEN '⚠️ Проверьте: возможно нет operatorPM'
        ELSE '⚠️ Проверьте вручную'
    END as operatorPM_status
FROM pg_policies
WHERE tablename = 'equipment'
AND cmd = 'ALL'
ORDER BY policyname;

-- Итоговая проверка: есть ли политики, которые разрешают INSERT для operatorPM
SELECT 
    CASE 
        WHEN COUNT(CASE WHEN (cmd = 'INSERT' OR cmd = 'ALL') 
                        AND (qual::text LIKE '%operatorPM%' OR with_check::text LIKE '%operatorPM%') 
                   THEN 1 END) > 0 
        THEN '✅ Есть политики, разрешающие INSERT для operatorPM'
        ELSE '❌ НЕТ политик, разрешающих INSERT для operatorPM'
    END as final_status,
    COUNT(CASE WHEN (cmd = 'INSERT' OR cmd = 'ALL') 
               AND (qual::text LIKE '%operatorPM%' OR with_check::text LIKE '%operatorPM%') 
          THEN 1 END) as policies_with_operatorPM
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL');

