-- Проверка и создание таблицы уведомлений
-- Проблема: уведомления не отображаются, возможно таблица не создана

-- 1. Проверяем, существует ли таблица notifications
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name = 'notifications';

-- 2. Если таблица не существует, создаем её
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    related_id UUID,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Создаем индексы для производительности
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);

-- 4. Включаем RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 5. Создаем RLS политики (разрешаем все операции для простоты)
CREATE POLICY "Allow all operations on notifications" ON notifications
    FOR ALL USING (true) WITH CHECK (true);

-- 6. Создаем триггер для автоматического обновления updated_at
CREATE TRIGGER update_notifications_updated_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. Проверяем структуру таблицы
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'notifications' 
ORDER BY ordinal_position;

-- 8. Проверяем существующие уведомления
SELECT 
    id,
    user_id,
    title,
    message,
    type,
    is_read,
    created_at
FROM notifications 
ORDER BY created_at DESC 
LIMIT 10;
