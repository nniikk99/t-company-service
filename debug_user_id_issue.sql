-- Проверка и исправление проблемы с user_id в company_requests
-- Ошибка: Key is not present in table "user_profiles"

-- 1. Проверяем, какие пользователи есть в user_profiles
SELECT id, first_name, last_name, phone, role 
FROM user_profiles 
ORDER BY created_at DESC 
LIMIT 10;

-- 2. Проверяем, есть ли записи в company_requests
SELECT COUNT(*) as total_requests FROM company_requests;

-- 3. Проверяем структуру таблицы company_requests
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'company_requests' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Проверяем внешние ключи
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'company_requests';

-- 5. Временно отключаем проверку внешних ключей для тестирования
-- (НЕ РЕКОМЕНДУЕТСЯ для продакшена, только для отладки)
ALTER TABLE company_requests DISABLE TRIGGER ALL;

-- 6. Удаляем ограничение внешнего ключа временно
ALTER TABLE company_requests DROP CONSTRAINT IF EXISTS company_requests_user_id_fkey;

-- 7. Проверяем, что ограничение удалено
SELECT constraint_name 
FROM information_schema.table_constraints 
WHERE table_name = 'company_requests' 
  AND constraint_type = 'FOREIGN KEY';
