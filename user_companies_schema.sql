-- Схема для управления несколькими компаниями пользователя
-- Позволяет пользователю быть ответственным лицом в нескольких компаниях

-- Таблица связей пользователь-компания
CREATE TABLE user_companies (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    company_inn VARCHAR(20) NOT NULL, -- ИНН компании для быстрого поиска
    role VARCHAR(50) NOT NULL CHECK (role IN ('companyResponsible', 'siteManager', 'operatorPM')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Уникальность: один пользователь может быть в одной компании только один раз
    UNIQUE(user_id, company_id),
    UNIQUE(user_id, company_inn)
);

-- Таблица заявок на создание новых компаний
CREATE TABLE company_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    company_inn VARCHAR(20) NOT NULL UNIQUE,
    company_address TEXT,
    company_phone VARCHAR(50),
    company_email VARCHAR(255),
    requested_role VARCHAR(50) DEFAULT 'companyResponsible' CHECK (requested_role IN ('companyResponsible', 'siteManager', 'operatorPM')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Добавляем поле company_inn в таблицу companies (если еще нет)
ALTER TABLE companies 
ADD COLUMN IF NOT EXISTS company_inn VARCHAR(20) UNIQUE;

-- Индексы для производительности
CREATE INDEX IF NOT EXISTS idx_user_companies_user_id ON user_companies(user_id);
CREATE INDEX IF NOT EXISTS idx_user_companies_company_id ON user_companies(company_id);
CREATE INDEX IF NOT EXISTS idx_user_companies_company_inn ON user_companies(company_inn);
CREATE INDEX IF NOT EXISTS idx_user_companies_status ON user_companies(status);
CREATE INDEX IF NOT EXISTS idx_company_requests_user_id ON company_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_company_requests_status ON company_requests(status);
CREATE INDEX IF NOT EXISTS idx_companies_inn ON companies(company_inn);

-- RLS Policies для user_companies
ALTER TABLE user_companies ENABLE ROW LEVEL SECURITY;

-- Пользователи видят только свои связи с компаниями
CREATE POLICY "Users can view own company connections" ON user_companies
    FOR SELECT USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')
        )
    );

-- Пользователи могут создавать заявки на присоединение
CREATE POLICY "Users can create company connections" ON user_companies
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND status = 'pending'
    );

-- Админы могут подтверждать/отклонять заявки
CREATE POLICY "Admins can manage company connections" ON user_companies
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')
        )
    );

-- RLS Policies для company_requests
ALTER TABLE company_requests ENABLE ROW LEVEL SECURITY;

-- Пользователи видят только свои заявки
CREATE POLICY "Users can view own company requests" ON company_requests
    FOR SELECT USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')
        )
    );

-- Пользователи могут создавать заявки на создание компаний
CREATE POLICY "Users can create company requests" ON company_requests
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND status = 'pending'
    );

-- Админы могут подтверждать/отклонять заявки на создание компаний
CREATE POLICY "Admins can manage company requests" ON company_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')
        )
    );

-- Триггеры для автоматического обновления updated_at
CREATE TRIGGER update_user_companies_updated_at 
    BEFORE UPDATE ON user_companies 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_requests_updated_at 
    BEFORE UPDATE ON company_requests 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Функция для проверки уникальности ответственного лица в компании
CREATE OR REPLACE FUNCTION check_company_responsible_uniqueness()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверяем, что в компании может быть только один companyResponsible
    IF NEW.role = 'companyResponsible' AND NEW.status = 'approved' THEN
        IF EXISTS (
            SELECT 1 FROM user_companies 
            WHERE company_id = NEW.company_id 
            AND role = 'companyResponsible' 
            AND status = 'approved'
            AND id != NEW.id
        ) THEN
            RAISE EXCEPTION 'Company already has a responsible person';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для проверки уникальности ответственного лица
CREATE TRIGGER check_company_responsible_trigger
    BEFORE INSERT OR UPDATE ON user_companies
    FOR EACH ROW EXECUTE FUNCTION check_company_responsible_uniqueness();

-- Функция для автоматического создания компании при подтверждении заявки
CREATE OR REPLACE FUNCTION create_company_from_request()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
BEGIN
    -- Если заявка одобрена, создаем компанию
    IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
        -- Создаем компанию
        INSERT INTO companies (name, company_inn, description, contact_email, contact_phone, address)
        VALUES (NEW.company_name, NEW.company_inn, 'Создано из заявки пользователя', NEW.company_email, NEW.company_phone, NEW.company_address)
        RETURNING id INTO new_company_id;
        
        -- Создаем связь пользователя с компанией
        INSERT INTO user_companies (user_id, company_id, company_inn, role, status, approved_by, approved_at)
        VALUES (NEW.user_id, new_company_id, NEW.company_inn, NEW.requested_role, 'approved', NEW.approved_by, NEW.approved_at);
        
        -- Обновляем профиль пользователя с новой компанией (если это первая компания)
        UPDATE user_profiles 
        SET company_id = new_company_id, company_inn = NEW.company_inn
        WHERE id = NEW.user_id AND company_id IS NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического создания компании
CREATE TRIGGER create_company_from_request_trigger
    AFTER UPDATE ON company_requests
    FOR EACH ROW EXECUTE FUNCTION create_company_from_request();
