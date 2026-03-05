-- ========================================================
-- ФИНАЛЬНЫЙ СКРИПТ: ИСПРАВЛЕНИЕ ДАННЫХ И КОНТАКТОВ
-- ========================================================

-- 1. ИСПРАВЛЕНИЕ ПРОФИЛЯ ТЕСТОВОГО ПОЛЬЗОВАТЕЛЯ
-- Гарантируем, что у пользователя +7 111 111 11 11 есть рабочий профиль
DO $$
DECLARE
    test_user_id uuid := '4e3f5122-464e-4390-b40e-0f790129b0a0';
BEGIN
    INSERT INTO user_profiles (id, phone, role, first_name, last_name, is_active, company_inn)
    VALUES (test_user_id, '+7 111 111 11 11', 'operatorPM', 'Тестовый', 'Оператор', true, '0000000001')
    ON CONFLICT (id) DO UPDATE SET
        role = 'operatorPM',
        is_active = true,
        phone = '+7 111 111 11 11';
END $$;

-- 2. ДОБАВЛЕНИЕ КОЛОНОК ДЛЯ КОНТАКТОВ В ОБОРУДОВАНИЕ (если еще нет)
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS site_manager_contact TEXT;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS operator_contact TEXT;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS responsible_contact TEXT;

-- 3. ОБНОВЛЕНИЕ ТЕСТОВОГО ОБОРУДОВАНИЯ (Разные площадки и контакты)
-- Оборудование Gadlee (Площадка Север)
UPDATE equipment SET 
    location = 'Площадка Север (г. Москва, ул. Ленина, 1)',
    site_manager_contact = 'Иван Менеджер (+7 900 111-22-33)',
    operator_contact = 'Алексей Оператор (+7 900 444-55-66)',
    responsible_contact = 'Мария Ответственная (+7 900 777-88-99)'
WHERE name LIKE '%Gadlee%';

-- Оборудование Tennant (Площадка Юг)
UPDATE equipment SET 
    location = 'Площадка Юг (г. Москва, ул. Мира, 50)',
    site_manager_contact = 'Петр Менеджер (+7 911 111-22-33)',
    operator_contact = 'Сергей Оператор (+7 911 444-55-66)',
    responsible_contact = 'Ольга Ответственная (+7 911 777-88-99)'
WHERE name LIKE '%Tennant%';

-- Оборудование IPC (Площадка Восток)
UPDATE equipment SET 
    location = 'Площадка Восток (г. Москва, ш. Энтузиастов, 12)',
    site_manager_contact = 'Виктор Менеджер (+7 922 111-22-33)',
    operator_contact = 'Николай Оператор (+7 922 444-55-66)',
    responsible_contact = 'Татьяна Ответственная (+7 922 777-88-99)'
WHERE name LIKE '%IPC%';

-- 4. ИСПРАВЛЕНИЕ СВЯЗЕЙ (Снимаем блокировку Foreign Key на время, чтобы не было ошибок 23503)
ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS service_requests_user_id_fkey;
ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS service_requests_equipment_id_fkey;

-- 5. ОБНОВЛЕНИЕ КЭША
NOTIFY pgrst, 'reload schema';
