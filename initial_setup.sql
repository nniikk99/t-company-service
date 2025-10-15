-- Быстрая настройка для первоначального тестирования
-- Выполните этот SQL в Supabase SQL Editor

-- Создаем таблицу компаний
CREATE TABLE IF NOT EXISTS companies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Создаем тестовую компанию
INSERT INTO companies (name, description, contact_email) VALUES 
('ООО "Тест Компания"', 'Первая тестовая компания для разработки', 'test@company.ru')
ON CONFLICT DO NOTHING;

-- Включаем RLS (Row Level Security)
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Создаем политику для чтения (пока разрешаем всем для тестирования)
CREATE POLICY "Allow read access" ON companies FOR SELECT USING (true);

-- Создаем политику для создания (пока разрешаем всем для тестирования)
CREATE POLICY "Allow insert access" ON companies FOR INSERT WITH CHECK (true);
