-- T-Co Service Database Schema
-- Схема базы данных для Telegram Mini App системы сервисных заявок

-- Включаем RLS (Row Level Security)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Таблица компаний
CREATE TABLE companies (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица площадок (локаций) компании
CREATE TABLE sites (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    description TEXT,
    contact_person VARCHAR(255),
    contact_phone VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица пользователей (расширяет auth.users)
CREATE TABLE user_profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'client_manager', 'responsible_person', 'contact_person')),
    telegram_id BIGINT UNIQUE,
    telegram_username VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица оборудования
CREATE TABLE equipment (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    model VARCHAR(255) NOT NULL,
    manufacturer VARCHAR(255),
    serial_number VARCHAR(100),
    inventory_number VARCHAR(100),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'broken', 'inactive')),
    purchase_date DATE,
    warranty_expiry DATE,
    responsible_user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    description TEXT,
    specifications JSONB,
    images TEXT[], -- массив URL изображений
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица сервисных заявок
CREATE TABLE service_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('maintenance', 'repair', 'inspection', 'parts_replacement')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'in_progress', 'completed', 'cancelled', 'rejected')),
    approved_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    scheduled_date TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    attachments TEXT[], -- массив URL файлов
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица заявок на запчасти
CREATE TABLE parts_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    service_request_id UUID REFERENCES service_requests(id) ON DELETE SET NULL,
    part_name VARCHAR(255) NOT NULL,
    part_number VARCHAR(100),
    quantity INTEGER NOT NULL DEFAULT 1,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'ordered', 'received', 'installed', 'cancelled')),
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    supplier VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица цен для компаний
CREATE TABLE company_prices (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    service_type VARCHAR(100) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'RUB',
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(company_id, service_type, item_name)
);

-- Таблица уведомлений
CREATE TABLE notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('request_created', 'request_approved', 'request_rejected', 'request_completed', 'parts_ordered', 'maintenance_due')),
    related_id UUID, -- ID связанной сущности (заявки, оборудования и т.д.)
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Индексы для производительности
CREATE INDEX idx_sites_company_id ON sites(company_id);
CREATE INDEX idx_user_profiles_company_id ON user_profiles(company_id);
CREATE INDEX idx_equipment_company_id ON equipment(company_id);
CREATE INDEX idx_equipment_site_id ON equipment(site_id);
CREATE INDEX idx_service_requests_company_id ON service_requests(company_id);
CREATE INDEX idx_service_requests_equipment_id ON service_requests(equipment_id);
CREATE INDEX idx_service_requests_user_id ON service_requests(user_id);
CREATE INDEX idx_parts_requests_company_id ON parts_requests(company_id);
CREATE INDEX idx_parts_requests_equipment_id ON parts_requests(equipment_id);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);

-- RLS Policies

-- Companies - админы видят все, остальные только свою компанию
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all companies" ON companies
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Users can view own company" ON companies
    FOR SELECT USING (
        id IN (
            SELECT company_id FROM user_profiles 
            WHERE id = auth.uid()
        )
    );

-- Sites - пользователи видят только площадки своей компании
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view company sites" ON sites
    FOR SELECT USING (
        company_id IN (
            SELECT company_id FROM user_profiles 
            WHERE id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Equipment - пользователи видят оборудование своей компании
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view company equipment" ON equipment
    FOR SELECT USING (
        company_id IN (
            SELECT company_id FROM user_profiles 
            WHERE id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- User Profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view profiles" ON user_profiles
    FOR SELECT USING (
        id = auth.uid() OR
        company_id IN (
            SELECT company_id FROM user_profiles 
            WHERE id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Service Requests
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view company requests" ON service_requests
    FOR SELECT USING (
        company_id IN (
            SELECT company_id FROM user_profiles 
            WHERE id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Аналогично для остальных таблиц...
-- (Parts requests, Company prices, Notifications)

-- Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггеры для автоматического обновления updated_at
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON sites FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_equipment_updated_at BEFORE UPDATE ON equipment FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_service_requests_updated_at BEFORE UPDATE ON service_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_parts_requests_updated_at BEFORE UPDATE ON parts_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_company_prices_updated_at BEFORE UPDATE ON company_prices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
