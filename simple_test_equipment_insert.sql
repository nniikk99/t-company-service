-- Простая проверка создания оборудования
-- Выполните от имени ответственного лица (companyResponsible)

-- ШАГ 1: Проверяем текущего пользователя
SELECT 
    id as user_id,
    email,
    role,
    company_id,
    company_inn
FROM user_profiles
WHERE id = auth.uid();

-- ШАГ 2: Если company_id НЕ NULL, скопируйте его и вставьте в следующий запрос
-- ЗАМЕНИТЕ значения ниже на результаты из Шага 1:

-- Пример вставки (ЗАМЕНИТЕ значения):
-- INSERT INTO equipment (
--     id,
--     company_id,
--     company_inn,
--     name,
--     manufacturer,
--     model,
--     status,
--     location,
--     address
-- ) VALUES (
--     gen_random_uuid(),
--     'СКОПИРУЙТЕ_ВАШ_COMPANY_ID_ИЗ_ШАГА_1',
--     'СКОПИРУЙТЕ_ВАШ_COMPANY_INN_ИЗ_ШАГА_1',
--     'Тестовое оборудование',
--     'Test',
--     'Model-1',
--     'active',
--     'Тест',
--     'Тест'
-- );

