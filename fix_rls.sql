-- 1. Удаляем старые политики для таблицы сообщений
DROP POLICY IF EXISTS "Users involved in request can see messages" ON request_messages;
DROP POLICY IF EXISTS "Users involved in request can send messages" ON request_messages;

-- 2. Политика на ПРОСМОТР сообщений
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

-- 3. Политика на ОТПРАВКУ сообщений
CREATE POLICY "Users involved in request can send messages" ON request_messages
    FOR INSERT
    WITH CHECK (
        (auth.uid() = sender_id) AND
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
