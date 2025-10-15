-- ШАГ 2: Создаем записи для первых компаний пользователей

-- 1. Пользователь test - добавляем его первую компанию "Test company" (ИНН 0000000001)
INSERT INTO user_companies (
    user_id,
    company_id,
    company_inn,
    company_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    '39fa2176-54c2-412f-9d01-52ef9cbf3c31' as user_id,
    c.id as company_id,
    '0000000001' as company_inn,
    'Test company' as company_name,
    'companyResponsible' as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM companies c 
WHERE c.company_inn = '0000000001';

-- 2. Админ Михаил Басалыгин - добавляем T-Company (ИНН 0000000000)
INSERT INTO user_companies (
    user_id,
    company_id,
    company_inn,
    company_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    '00000000-0000-0000-0000-000000000001' as user_id,
    c.id as company_id,
    '0000000000' as company_inn,
    'T-Company' as company_name,
    'superAdmin' as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM companies c 
WHERE c.company_inn = '0000000000';

-- 3. Мария Петрова - добавляем её компанию (ИНН 9876543210)
INSERT INTO user_companies (
    user_id,
    company_id,
    company_inn,
    company_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    '9522bbae-8aff-4a8b-9c1d-123456789abc' as user_id,
    c.id as company_id,
    '9876543210' as company_inn,
    COALESCE(c.name, 'Компания Марии') as company_name,
    'companyResponsible' as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM companies c 
WHERE c.company_inn = '9876543210';

-- 4. Имя Фамилия - добавляем его компанию (ИНН 1234567890)
INSERT INTO user_companies (
    user_id,
    company_id,
    company_inn,
    company_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890' as user_id,
    c.id as company_id,
    '1234567890' as company_inn,
    COALESCE(c.name, 'Компания Имя') as company_name,
    'companyResponsible' as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM companies c 
WHERE c.company_inn = '1234567890';

-- 5. Юшко - добавляем его компанию (ИНН 0000000001)
INSERT INTO user_companies (
    user_id,
    company_id,
    company_inn,
    company_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    'f1e2d3c4-b5a6-9870-fedc-ba0987654321' as user_id,
    c.id as company_id,
    '0000000001' as company_inn,
    COALESCE(c.name, 'Компания Юшко') as company_name,
    'companyResponsible' as role,
    'approved' as status,
    NOW() as created_at,
    NOW() as updated_at
FROM companies c 
WHERE c.company_inn = '0000000001';
