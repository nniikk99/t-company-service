-- Исправление ролей пользователей в базе данных
-- Проблема: роли сохранены в snake_case, а код ожидает camelCase

-- 1. Проверяем текущие роли
SELECT DISTINCT role FROM user_profiles ORDER BY role;

-- 2. Обновляем роли на camelCase формат
UPDATE user_profiles SET role = 'pendingApproval' WHERE role = 'pending_approval';
UPDATE user_profiles SET role = 'operatorPM' WHERE role = 'operator_pm';
UPDATE user_profiles SET role = 'siteManager' WHERE role = 'site_manager';
UPDATE user_profiles SET role = 'companyResponsible' WHERE role = 'company_responsible';
UPDATE user_profiles SET role = 'superAdmin' WHERE role = 'super_admin';

-- 3. Проверяем результат
SELECT DISTINCT role FROM user_profiles ORDER BY role;

-- 4. Проверяем конкретно пользователя Михаила Басалыгина
SELECT 
    id,
    first_name,
    last_name,
    phone,
    role,
    company_inn
FROM user_profiles 
WHERE first_name ILIKE '%михаил%' 
   OR last_name ILIKE '%басалыгин%'
   OR id = '00000000-0000-0000-0000-000000000001';

-- 5. Если нужно принудительно установить роль супер-админа
-- Раскомментируйте следующую строку:
-- UPDATE user_profiles SET role = 'superAdmin' WHERE id = '00000000-0000-0000-0000-000000000001';
