-- Подготовка тестовых данных для проверки работы системы заявок
-- Выполнять последовательно, проверяя результаты

-- ============================================
-- ШАГ 1: Создание тестового поставщика
-- ============================================

-- Сначала создаем пользователя в Supabase Auth (это нужно сделать через UI или API)
-- Email: supplier@test.com
-- Password: Test123456!

-- Затем создаем профиль поставщика в user_profiles
-- ВАЖНО: Замените 'SUPPLIER_USER_ID' на реальный UUID из auth.users после создания
INSERT INTO user_profiles (
    id,
    email,
    first_name,
    last_name,
    phone,
    role,
    position,
    consent_to_personal_data,
    is_active
) VALUES (
    'SUPPLIER_USER_ID', -- Заменить на реальный UUID
    'supplier@test.com',
    'Иван',
    'Поставщиков',
    '+7 (999) 123-45-67',
    'supplier',
    'Директор по сервису',
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    role = 'supplier',
    first_name = 'Иван',
    last_name = 'Поставщиков';

-- ============================================
-- ШАГ 2: Создание тестовых инженеров для поставщика
-- ============================================

-- Инженер 1
-- Email: engineer1@test.com, Password: Test123456!
INSERT INTO user_profiles (
    id,
    email,
    first_name,
    last_name,
    phone,
    role,
    position,
    supplier_id, -- Привязываем к поставщику
    consent_to_personal_data,
    is_active
) VALUES (
    'ENGINEER1_USER_ID', -- Заменить на реальный UUID
    'engineer1@test.com',
    'Петр',
    'Инженеров',
    '+7 (999) 111-11-11',
    'engineer',
    'Инженер-сервисник',
    'SUPPLIER_USER_ID', -- ID поставщика
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    role = 'engineer',
    supplier_id = 'SUPPLIER_USER_ID';

-- Инженер 2
-- Email: engineer2@test.com, Password: Test123456!
INSERT INTO user_profiles (
    id,
    email,
    first_name,
    last_name,
    phone,
    role,
    position,
    supplier_id,
    consent_to_personal_data,
    is_active
) VALUES (
    'ENGINEER2_USER_ID', -- Заменить на реальный UUID
    'engineer2@test.com',
    'Сергей',
    'Мастеров',
    '+7 (999) 222-22-22',
    'engineer',
    'Старший инженер',
    'SUPPLIER_USER_ID', -- ID поставщика
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    role = 'engineer',
    supplier_id = 'SUPPLIER_USER_ID';

-- ============================================
-- ШАГ 3: Создание тестовой компании-клиента
-- ============================================

-- Создаем компанию
INSERT INTO companies (
    id,
    name,
    inn,
    address,
    phone,
    email,
    org_type
) VALUES (
    gen_random_uuid(),
    'ООО "Тестовая компания"',
    '7701234567',
    'г. Москва, ул. Тестовая, д. 1',
    '+7 (495) 123-45-67',
    'test@company.ru',
    'client'
)
ON CONFLICT (inn) DO UPDATE SET
    name = 'ООО "Тестовая компания"'
RETURNING id; -- Запомните этот ID

-- ============================================
-- ШАГ 4: Создание ответственного лица компании
-- ============================================

-- Email: responsible@test.com, Password: Test123456!
INSERT INTO user_profiles (
    id,
    email,
    first_name,
    last_name,
    phone,
    role,
    position,
    company_id, -- ID компании из предыдущего шага
    company_inn,
    consent_to_personal_data,
    is_active
) VALUES (
    'RESPONSIBLE_USER_ID', -- Заменить на реальный UUID
    'responsible@test.com',
    'Мария',
    'Ответственная',
    '+7 (999) 333-33-33',
    'companyResponsible',
    'Директор',
    'COMPANY_ID', -- ID компании
    '7701234567',
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    role = 'companyResponsible',
    company_id = 'COMPANY_ID';

-- ============================================
-- ШАГ 5: Создание оператора ПМ
-- ============================================

-- Email: operator@test.com, Password: Test123456!
INSERT INTO user_profiles (
    id,
    email,
    first_name,
    last_name,
    phone,
    role,
    position,
    company_id,
    company_inn,
    consent_to_personal_data,
    is_active
) VALUES (
    'OPERATOR_USER_ID', -- Заменить на реальный UUID
    'operator@test.com',
    'Алексей',
    'Операторов',
    '+7 (999) 444-44-44',
    'operatorPM',
    'Оператор',
    'COMPANY_ID', -- ID компании
    '7701234567',
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    role = 'operatorPM',
    company_id = 'COMPANY_ID';

-- ============================================
-- ШАГ 6: Создание площадки
-- ============================================

INSERT INTO sites (
    id,
    company_id,
    name,
    address,
    contact_person,
    contact_phone
) VALUES (
    gen_random_uuid(),
    'COMPANY_ID', -- ID компании
    'Производственная площадка №1',
    'г. Москва, ул. Производственная, д. 10',
    'Мария Ответственная',
    '+7 (999) 333-33-33'
)
RETURNING id; -- Запомните этот ID

-- ============================================
-- ШАГ 7: Создание оборудования с привязкой к поставщику
-- ============================================

INSERT INTO equipment (
    id,
    company_id,
    company_inn,
    supplier_id, -- ВАЖНО: привязываем к поставщику
    site_id,
    name,
    manufacturer,
    model,
    serial_number,
    status,
    location,
    address
) VALUES (
    gen_random_uuid(),
    'COMPANY_ID', -- ID компании
    '7701234567',
    'SUPPLIER_USER_ID', -- ID поставщика - ВАЖНО!
    'SITE_ID', -- ID площадки
    'Дизельный генератор',
    'Caterpillar',
    'C15',
    'CAT123456789',
    'active',
    'Производственная площадка №1',
    'г. Москва, ул. Производственная, д. 10'
)
RETURNING id; -- Запомните этот ID для создания заявки

-- ============================================
-- ПРОВЕРКА: Просмотр созданных данных
-- ============================================

-- Проверяем поставщика и его инженеров
SELECT 
    id,
    email,
    first_name,
    last_name,
    role,
    supplier_id
FROM user_profiles
WHERE role IN ('supplier', 'engineer')
ORDER BY role, first_name;

-- Проверяем компанию и её сотрудников
SELECT 
    up.id,
    up.email,
    up.first_name,
    up.last_name,
    up.role,
    up.company_id,
    c.name as company_name
FROM user_profiles up
LEFT JOIN companies c ON c.id = up.company_id
WHERE up.role IN ('companyResponsible', 'operatorPM', 'siteManager')
ORDER BY up.role, up.first_name;

-- Проверяем оборудование с поставщиком
SELECT 
    e.id,
    e.name,
    e.manufacturer,
    e.model,
    e.supplier_id,
    up.first_name || ' ' || up.last_name as supplier_name,
    c.name as company_name
FROM equipment e
LEFT JOIN user_profiles up ON up.id = e.supplier_id
LEFT JOIN companies c ON c.id = e.company_id
ORDER BY e.created_at DESC
LIMIT 10;

