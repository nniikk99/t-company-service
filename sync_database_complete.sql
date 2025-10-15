-- Полная синхронизация базы данных с актуальным кодом
-- Выполните этот скрипт, если что-то отсутствует

-- 1. Добавляем недостающие поля company_inn
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20);

ALTER TABLE public.sites 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20);

ALTER TABLE public.equipment 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20);

ALTER TABLE public.companies 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20) UNIQUE;

-- 2. Создаем таблицу user_companies (если не существует)
CREATE TABLE IF NOT EXISTS user_companies (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    company_inn VARCHAR(20) NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('companyResponsible', 'siteManager', 'operatorPM')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, company_id),
    UNIQUE(user_id, company_inn)
);

-- 3. Создаем таблицу company_requests (если не существует)
CREATE TABLE IF NOT EXISTS company_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    company_inn VARCHAR(20) NOT NULL UNIQUE,
    company_address TEXT,
    company_phone VARCHAR(50),
    company_email VARCHAR(255),
    requested_role VARCHAR(50) DEFAULT 'companyResponsible' CHECK (requested_role IN ('companyResponsible', 'siteManager', 'operatorPM')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Создаем таблицу notifications (если не существует)
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

-- 5. Создаем индексы для производительности
CREATE INDEX IF NOT EXISTS idx_user_companies_user_id ON user_companies(user_id);
CREATE INDEX IF NOT EXISTS idx_user_companies_company_id ON user_companies(company_id);
CREATE INDEX IF NOT EXISTS idx_user_companies_company_inn ON user_companies(company_inn);
CREATE INDEX IF NOT EXISTS idx_user_companies_status ON user_companies(status);

CREATE INDEX IF NOT EXISTS idx_company_requests_user_id ON company_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_company_requests_status ON company_requests(status);
CREATE INDEX IF NOT EXISTS idx_company_requests_company_inn ON company_requests(company_inn);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);

CREATE INDEX IF NOT EXISTS idx_sites_company_inn ON sites(company_inn);
CREATE INDEX IF NOT EXISTS idx_equipment_company_inn ON equipment(company_inn);
CREATE INDEX IF NOT EXISTS idx_user_profiles_company_inn ON user_profiles(company_inn);
CREATE INDEX IF NOT EXISTS idx_companies_inn ON companies(company_inn);

-- 6. Включаем RLS для новых таблиц
ALTER TABLE user_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 7. Создаем простые RLS политики (разрешаем все операции)
DROP POLICY IF EXISTS "Allow all operations on user_companies" ON user_companies;
CREATE POLICY "Allow all operations on user_companies" ON user_companies
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all operations on company_requests" ON company_requests;
CREATE POLICY "Allow all operations on company_requests" ON company_requests
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all operations on notifications" ON notifications;
CREATE POLICY "Allow all operations on notifications" ON notifications
    FOR ALL USING (true) WITH CHECK (true);

-- 8. Создаем функцию для обновления updated_at (если не существует)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 9. Создаем триггеры для автоматического обновления updated_at
DROP TRIGGER IF EXISTS update_user_companies_updated_at ON user_companies;
CREATE TRIGGER update_user_companies_updated_at
    BEFORE UPDATE ON user_companies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_company_requests_updated_at ON company_requests;
CREATE TRIGGER update_company_requests_updated_at
    BEFORE UPDATE ON company_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_notifications_updated_at ON notifications;
CREATE TRIGGER update_notifications_updated_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 10. Обновляем роли в user_profiles (если нужно)
-- Добавляем новые роли в CHECK constraint
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check 
CHECK (role IN ('superAdmin', 'administrator', 'companyResponsible', 'siteManager', 'operatorPM', 'pendingApproval'));

-- 11. Проверяем результат
SELECT 'SYNC COMPLETED' as status;
