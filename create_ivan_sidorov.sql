-- Создание пользователя Иван Сидоров в Supabase
-- ID: 00000000-0000-0000-0000-000000000003

-- Проверяем, существует ли пользователь
SELECT * FROM user_profiles WHERE id = '00000000-0000-0000-0000-000000000003';

-- Если не существует, создаем его
INSERT INTO user_profiles (
    id,
    first_name,
    last_name,
    email,
    phone,
    role,
    position,
    company_id,
    company_inn,
    can_manage_requests_independently,
    assigned_site_ids,
    created_by,
    password_hash,
    telegram_id,
    consent_to_personal_data,
    is_active,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000003',
    'Иван',
    'Сидоров',
    'ivan@lenta.ru',
    '+7 (495) 987-65-43',
    'siteManager',
    'Менеджер объекта',
    '00000000-0000-0000-0000-000000000001',
    '0000000001',
    false,
    ARRAY['fe8767e3-7490-4f5a-ab73-9eec66c235af', '00000000-0000-0000-0000-000000000101', 'e98811cb-fe04-4eb1-ac4f-a62d4884bd02'],
    '9522bbae-8aff-4a09-a06f-62a5dcbd614a',
    '6f85779a3c91246695b89b4e273863d6546e8facce1946ff7ca05a59e447a5af', -- SHA-256 hash for 'manager123'
    '111222333',
    true,
    true,
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role,
    position = EXCLUDED.position,
    company_id = EXCLUDED.company_id,
    company_inn = EXCLUDED.company_inn,
    can_manage_requests_independently = EXCLUDED.can_manage_requests_independently,
    assigned_site_ids = EXCLUDED.assigned_site_ids,
    created_by = EXCLUDED.created_by,
    password_hash = EXCLUDED.password_hash,
    telegram_id = EXCLUDED.telegram_id,
    consent_to_personal_data = EXCLUDED.consent_to_personal_data,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Проверяем результат
SELECT * FROM user_profiles WHERE id = '00000000-0000-0000-0000-000000000003';
