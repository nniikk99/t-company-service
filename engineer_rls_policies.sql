-- RLS ПОЛИТИКИ ДЛЯ РОЛИ "ИНЖЕНЕР"

-- 1. Политика для доступа инженеров к своим назначенным заявкам
CREATE POLICY "engineers_can_view_assigned_requests" ON service_requests
    FOR SELECT
    TO authenticated
    USING (
        assigned_engineer_id = auth.uid()::text::uuid
        AND EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid()::text::uuid 
            AND role = 'engineer'
        )
    );

-- 2. Политика для обновления заявок инженерами
CREATE POLICY "engineers_can_update_assigned_requests" ON service_requests
    FOR UPDATE
    TO authenticated
    USING (
        assigned_engineer_id = auth.uid()::text::uuid
        AND EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid()::text::uuid 
            AND role = 'engineer'
        )
    )
    WITH CHECK (
        assigned_engineer_id = auth.uid()::text::uuid
    );

-- 3. Политика для администраторов - могут назначать заявки инженерам
CREATE POLICY "admins_can_assign_requests" ON service_requests
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid()::text::uuid 
            AND role IN ('superAdmin', 'Administrator')
        )
    );

-- 4. Политика для просмотра всех заявок администраторами
CREATE POLICY "admins_can_view_all_requests" ON service_requests
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid()::text::uuid 
            AND role IN ('superAdmin', 'Administrator')
        )
    );

-- 5. Проверяем существующие политики
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'service_requests';
