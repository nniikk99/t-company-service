-- Проверка текущего пользователя и попытка вставки оборудования
-- Выполните этот скрипт от имени ответственного лица

-- ШАГ 1: Смотрим данные текущего пользователя
SELECT 
    'Текущий пользователь' as info,
    id,
    email,
    first_name || ' ' || last_name as full_name,
    role,
    company_id,
    company_inn,
    position
FROM user_profiles
WHERE id = auth.uid();

-- ШАГ 2: Проверяем, есть ли политики INSERT для equipment
SELECT 
    'Политики для INSERT' as info,
    policyname,
    cmd,
    substring(with_check::text, 1, 300) as with_check_condition
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL')
ORDER BY cmd, policyname;

-- ШАГ 3: Тестируем вставку с реальным company_id
-- Этот запрос автоматически использует company_id текущего пользователя
WITH current_user_data AS (
    SELECT 
        id,
        company_id,
        company_inn,
        role
    FROM user_profiles
    WHERE id = auth.uid()
)
INSERT INTO equipment (
    id,
    company_id,
    company_inn,
    name,
    manufacturer,
    model,
    status,
    location,
    address,
    created_at
)
SELECT 
    gen_random_uuid(),
    company_id,
    company_inn,
    'Тестовое оборудование RLS',
    'Test Manufacturer',
    'Test Model 123',
    'active',
    'Тестовая площадка',
    'Тестовый адрес',
    now()
FROM current_user_data
RETURNING id, name, company_id;

-- Если вставка успешна: ✅ Политика работает!
-- Если ошибка: ❌ Проблема в политике или данных пользователя

