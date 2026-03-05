-- ========================================================
-- ИСПРАВЛЕНИЕ ЛОГИКИ СВЯЗЕЙ (ПЛОЩАДКИ, РОЛИ, КОНТАКТЫ)
-- ========================================================

-- 1. ОЧИСТКА ГИПОТЕТИЧЕСКИХ ДАННЫХ В ОБОРУДОВАНИИ (УБИРАЕМ ХАРДКОД)
-- Мы не должны хранить контакты прямо в оборудовании, если они зависят от площадки
-- Но для обратной совместимости мы их будем обновлять динамически из связей

-- 2. СОЗДАНИЕ/ОБНОВЛЕНИЕ ПЛОЩАДОК (SITES)
-- Допустим, у нас есть две основные площадки
INSERT INTO sites (id, company_id, name, address, company_inn)
VALUES 
    ('site-uuid-north-001', (SELECT id FROM companies WHERE inn = '0000000001' LIMIT 1), 'Склад Север', 'г. Москва, ул. Северная, д. 10', '0000000001'),
    ('site-uuid-south-002', (SELECT id FROM companies WHERE inn = '0000000001' LIMIT 1), 'ТЦ Южный', 'г. Москва, ул. Южная, д. 50', '0000000001')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, address = EXCLUDED.address;

-- 3. НАЗНАЧЕНИЕ МЕНЕДЖЕРОВ ПЛОЩАДОК
-- Создаем профили менеджеров, если их нет
INSERT INTO user_profiles (id, phone, role, first_name, last_name, is_active, company_inn, assigned_site_ids)
VALUES 
    ('manager-uuid-001', '+7 900 111-00-01', 'siteManager', 'Игорь', 'Северный', true, '0000000001', ARRAY['site-uuid-north-001']),
    ('manager-uuid-002', '+7 900 222-00-02', 'siteManager', 'Павел', 'Южный', true, '0000000001', ARRAY['site-uuid-south-002'])
ON CONFLICT (id) DO UPDATE SET role = 'siteManager', assigned_site_ids = EXCLUDED.assigned_site_ids;

-- Обновляем contact_person_id в таблице sites
UPDATE sites SET contact_person_id = 'manager-uuid-001' WHERE id = 'site-uuid-north-001';
UPDATE sites SET contact_person_id = 'manager-uuid-002' WHERE id = 'site-uuid-south-002';

-- 4. НАЗНАЧЕНИЕ ОТВЕТСТВЕННОГО ЛИЦА КОМПАНИИ (Oversees both sites)
INSERT INTO user_profiles (id, phone, role, first_name, last_name, is_active, company_inn)
VALUES 
    ('responsible-uuid-001', '+7 999 888-77-66', 'companyResponsible', 'Максим', 'Генеральный', true, '0000000001')
ON CONFLICT (id) DO UPDATE SET role = 'companyResponsible';

-- 5. ПРИВЯЗКА ОБОРУДОВАНИЯ К ПЛОЩАДКАМ
-- Допустим, Gadlee на Севере, Tennant на Юге
UPDATE equipment SET site_id = 'site-uuid-north-001', location = 'Склад Север', address = 'г. Москва, ул. Северная, д. 10' WHERE manufacturer = 'Gadlee';
UPDATE equipment SET site_id = 'site-uuid-south-002', location = 'ТЦ Южный', address = 'г. Москва, ул. Южная, д. 50' WHERE manufacturer = 'Tennant';

-- 6. СИНХРОНИЗАЦИЯ КОНТАКТОВ В EQUIPMENT (для упрощения запросов в приложении)
-- Хотя лучше делать JOIN, мы обновим поля для текущего состояния
UPDATE equipment e
SET 
    site_manager_contact = up_sm.first_name || ' ' || up_sm.last_name || ' (' || up_sm.phone || ')',
    responsible_contact = (
        SELECT up_cr.first_name || ' ' || up_cr.last_name || ' (' || up_cr.phone || ')'
        FROM user_profiles up_cr 
        WHERE up_cr.role = 'companyResponsible' 
        AND up_cr.company_inn = e.company_inn 
        LIMIT 1
    )
FROM sites s
LEFT JOIN user_profiles up_sm ON up_sm.id = s.contact_person_id
WHERE e.site_id = s.id;

-- 7. ПЕРЕЗАГРУЗКА
NOTIFY pgrst, 'reload schema';
