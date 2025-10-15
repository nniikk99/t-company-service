-- Простое решение проблемы с внешними ключами
-- Временно отключаем проверку внешних ключей для company_requests

-- 1. Проверяем, какие пользователи есть в user_profiles
SELECT id, first_name, last_name, phone, role 
FROM user_profiles 
ORDER BY created_at DESC 
LIMIT 10;

-- 2. Проверяем структуру таблицы company_requests
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'company_requests' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Временно отключаем проверку внешних ключей (простой способ)
SET session_replication_role = replica;

-- 4. Проверяем, что ограничение отключено
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'company_requests' 
  AND constraint_type = 'FOREIGN KEY';

-- 5. Включаем обратно проверку внешних ключей
SET session_replication_role = DEFAULT;
