-- Отключаем RLS для таблиц user_profiles и companies
-- Это необходимо для того, чтобы инструмент очистки базы данных в приложении
-- мог удалять тестовые данные без ошибок доступа (так как используется кастомная авторизация/роли)

ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;
