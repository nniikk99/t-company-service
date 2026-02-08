-- Исправление company_id для superAdmin
-- Проблема: company_id = NULL, поэтому RLS блокирует создание оборудования

-- ШАГ 1: Проверяем, какие компании есть в базе
SELECT 
    'Доступные компании' as info,
    id,
    name,
    inn,
    created_at
FROM companies
ORDER BY created_at DESC
LIMIT 10;

-- ШАГ 2: Если компаний нет, создаем тестовую компанию
-- Раскомментируйте, если нужно:
/*
INSERT INTO companies (
    id,
    name,
    inn,
    address,
    phone,
    email,
    created_at
) VALUES (
    gen_random_uuid(),
    'Главная компания',
    '0000000000',
    'Адрес компании',
    '+7 (999) 123-45-67',
    'admin@company.ru',
    now()
)
RETURNING id, name, inn;
*/

-- ШАГ 3: Обновляем company_id для superAdmin
-- ВАЖНО: Замените 'COMPANY_ID_FROM_STEP_1' на реальный ID компании из Шага 1
-- Или используйте первый доступный company_id:
UPDATE user_profiles
SET 
    company_id = (
        SELECT id FROM companies 
        WHERE inn = '0000000000' 
        LIMIT 1
    )
WHERE email = 'nniikk.9@mail.ru'
AND company_id IS NULL
AND role = 'superAdmin';

-- ШАГ 4: Проверяем результат
SELECT 
    'Проверка после обновления' as info,
    id,
    email,
    role,
    company_id,
    company_inn,
    CASE 
        WHEN company_id IS NULL THEN '❌ company_id все еще NULL'
        ELSE '✅ company_id обновлен'
    END as status
FROM user_profiles
WHERE email = 'nniikk.9@mail.ru';

-- ШАГ 5: Проверяем RLS политику для superAdmin
-- Политика должна разрешать superAdmin создавать оборудование без проверки company_id
SELECT 
    'Политика для superAdmin' as info,
    policyname,
    cmd,
    substring(with_check::text, 1, 400) as with_check_condition
FROM pg_policies
WHERE tablename = 'equipment'
AND (cmd = 'INSERT' OR cmd = 'ALL')
AND (
    with_check::text LIKE '%superAdmin%' 
    OR with_check::text LIKE '%administrator%'
);

