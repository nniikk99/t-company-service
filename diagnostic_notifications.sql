-- ════════════════════════════════════════════════
-- ШАГ 1: ДИАГНОСТИКА — запустить первым делом
-- Проверяем, срабатывает ли триггер вообще
-- ════════════════════════════════════════════════

-- Смотрим последние 5 строк в notifications
SELECT id, user_id, title, type, created_at
FROM notifications
ORDER BY created_at DESC
LIMIT 10;

-- Смотрим колонки в service_requests (убедимся, что поля называются правильно)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'service_requests'
  AND column_name IN ('user_id','company_id','company_inn','supplier_id','assigned_engineer_id','site_id');

-- Смотрим колонки в notifications (проверяем что related_id существует)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'notifications';
