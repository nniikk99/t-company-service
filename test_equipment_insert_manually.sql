-- Тест: Пробуем вставить оборудование вручную
-- Выполните этот скрипт от имени пользователя с ролью companyResponsible

-- ШАГ 1: Проверяем текущего пользователя
SELECT 
    id,
    email,
    role,
    company_id,
    company_inn
FROM user_profiles
WHERE id = auth.uid();

-- ШАГ 2: Пробуем вставить тестовое оборудование
-- ВАЖНО: Замените 'YOUR_COMPANY_ID' на company_id из Шага 1
INSERT INTO equipment (
    id,
    company_id,
    company_inn,
    name,
    manufacturer,
    model,
    status,
    location,
    address
) VALUES (
    gen_random_uuid(),
    'YOUR_COMPANY_ID', -- ЗАМЕНИТЬ на ваш company_id
    'YOUR_COMPANY_INN', -- ЗАМЕНИТЬ на ваш company_inn (если есть)
    'Тестовое оборудование',
    'Test',
    'Model-1',
    'active',
    'Тестовая площадка',
    'Тестовый адрес'
);

-- Если вставка прошла успешно:
-- ✅ Политика работает правильно
-- ❌ Проблема в коде приложения или данных

-- Если вставка не прошла:
-- Смотрим детали ошибки и проверяем политику

