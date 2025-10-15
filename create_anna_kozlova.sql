-- Создание пользователя Анна Козлова в Supabase
-- ID: 164fbf40-2862-49e5-a5c0-c22194a63bb2

-- Проверяем, существует ли пользователь
SELECT * FROM user_profiles WHERE id = '164fbf40-2862-49e5-a5c0-c22194a63bb2';

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
    assigned_site_ids,
    password_hash,
    telegram_id,
    consent_to_personal_data,
    is_active,
    created_at,
    updated_at
) VALUES (
    '164fbf40-2862-49e5-a5c0-c22194a63bb2',
    'Анна',
    'Козлова',
    'anna@test-company.ru',
    '+7 (495) 111-22-33',
    'operatorPM',
    'Оператор ПМ',
    '00000000-0000-0000-0000-000000000001',
    '0000000001',
    ARRAY['e98811cb-fe04-4eb1-ac4f-a62d4884bd02'],
    'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', -- SHA-256 hash for 'pending123'
    '444555666',
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
    assigned_site_ids = EXCLUDED.assigned_site_ids,
    password_hash = EXCLUDED.password_hash,
    telegram_id = EXCLUDED.telegram_id,
    consent_to_personal_data = EXCLUDED.consent_to_personal_data,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Проверяем результат
SELECT * FROM user_profiles WHERE id = '164fbf40-2862-49e5-a5c0-c22194a63bb2';
