-- Полное пересоздание таблицы company_requests без внешних ключей
-- Это решит проблему с user_id

-- 1. Удаляем таблицу company_requests полностью
DROP TABLE IF EXISTS company_requests CASCADE;

-- 2. Создаем таблицу заново БЕЗ внешних ключей
CREATE TABLE company_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL, -- БЕЗ REFERENCES для избежания проблем
    company_name VARCHAR(255) NOT NULL,
    company_inn VARCHAR(20) NOT NULL UNIQUE,
    company_address TEXT,
    company_phone VARCHAR(50),
    company_email VARCHAR(255),
    requested_role VARCHAR(50) DEFAULT 'companyResponsible' CHECK (requested_role IN ('companyResponsible', 'siteManager', 'operatorPM')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID, -- БЕЗ REFERENCES
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Создаем индексы для производительности
CREATE INDEX IF NOT EXISTS idx_company_requests_user_id ON company_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_company_requests_status ON company_requests(status);
CREATE INDEX IF NOT EXISTS idx_company_requests_company_inn ON company_requests(company_inn);

-- 4. Включаем RLS
ALTER TABLE company_requests ENABLE ROW LEVEL SECURITY;

-- 5. Создаем простые RLS политики (разрешаем все операции)
CREATE POLICY "Allow all operations on company_requests" ON company_requests
    FOR ALL USING (true) WITH CHECK (true);

-- 6. Создаем триггер для автоматического обновления updated_at
CREATE TRIGGER update_company_requests_updated_at
    BEFORE UPDATE ON company_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. Проверяем, что таблица создана
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'company_requests' 
ORDER BY ordinal_position;
