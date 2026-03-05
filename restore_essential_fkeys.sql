-- ВОССТАНОВЛЕНИЕ СВЯЗЕЙ ДЛЯ КОРРЕКТНОГО ОТОБРАЖЕНИЯ СПИСКА
-- Дата: 2026-02-23

-- 1. Возвращаем связь с оборудованием (критично для отображения названия техники в списке)
ALTER TABLE "service_requests" 
ADD CONSTRAINT "service_requests_equipment_id_fkey" 
FOREIGN KEY (equipment_id) REFERENCES equipment(id);

-- 2. Возвращаем связь с пользователями (критично для отображения ФИО создателя)
-- Мы используем таблицу user_profiles, так как база ссылается на нее в приложении
ALTER TABLE "service_requests" 
ADD CONSTRAINT "service_requests_user_id_fkey" 
FOREIGN KEY (user_id) REFERENCES user_profiles(id);

-- 3. Обновляем кэш
NOTIFY pgrst, 'reload schema';
