-- Создание таблицы для сообщений в заявках
CREATE TABLE IF NOT EXISTS request_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    message TEXT,
    attachments TEXT[], -- Массив ссылок на изображения
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_request_messages_request_id ON request_messages(request_id);
CREATE INDEX IF NOT EXISTS idx_request_messages_created_at ON request_messages(created_at);

-- Включаем RLS
ALTER TABLE request_messages ENABLE ROW LEVEL SECURITY;

-- Политики доступа
-- 1. Кто может видеть сообщения: администраторы, автор заявки, назначенный инженер, менеджеры площадки этой компании
CREATE POLICY "Users involved in request can see messages" ON request_messages
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM service_requests sr
            LEFT JOIN user_profiles up ON up.id = auth.uid()
            WHERE sr.id = request_messages.request_id
            AND (
                sr.user_id = auth.uid() OR 
                sr.assigned_engineer_id = auth.uid() OR
                up.role IN ('superAdmin', 'administrator') OR
                (up.role IN ('siteManager', 'companyResponsible') AND sr.company_inn = up.company_inn)
            )
        )
    );

-- 2. Кто может отправлять сообщения: те же пользователи
CREATE POLICY "Users involved in request can send messages" ON request_messages
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM service_requests sr
            LEFT JOIN user_profiles up ON up.id = auth.uid()
            WHERE sr.id = request_id
            AND (
                sr.user_id = auth.uid() OR 
                sr.assigned_engineer_id = auth.uid() OR
                up.role IN ('superAdmin', 'administrator') OR
                (up.role IN ('siteManager', 'companyResponsible') AND sr.company_inn = up.company_inn)
            )
        )
    );
