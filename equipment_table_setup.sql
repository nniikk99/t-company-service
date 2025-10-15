-- Создание таблицы equipment в Supabase
CREATE TABLE IF NOT EXISTS public.equipment (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    site_id UUID REFERENCES public.sites(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    manufacturer TEXT NOT NULL,
    model TEXT NOT NULL,
    modification TEXT,
    serial_number TEXT,
    location TEXT, -- для обратной совместимости
    address TEXT,  -- для обратной совместимости
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'inactive', 'broken')),
    responsible_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    description TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    installation_date TIMESTAMP WITH TIME ZONE,
    last_service_date TIMESTAMP WITH TIME ZONE,
    next_service_date TIMESTAMP WITH TIME ZONE,
    specifications JSONB,
    manuals TEXT[],
    photos TEXT[]
);

-- Создание индексов для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_equipment_company_id ON public.equipment(company_id);
CREATE INDEX IF NOT EXISTS idx_equipment_site_id ON public.equipment(site_id);
CREATE INDEX IF NOT EXISTS idx_equipment_status ON public.equipment(status);
CREATE INDEX IF NOT EXISTS idx_equipment_manufacturer ON public.equipment(manufacturer);
CREATE INDEX IF NOT EXISTS idx_equipment_model ON public.equipment(model);

-- Создание RLS (Row Level Security)
ALTER TABLE public.equipment ENABLE ROW LEVEL SECURITY;

-- Политика для админов (полный доступ)
CREATE POLICY "Admins can manage all equipment" ON public.equipment
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Политика для компаний (доступ только к своему оборудованию)
CREATE POLICY "Companies can manage their equipment" ON public.equipment
  FOR ALL USING (
    company_id IN (
      SELECT company_id FROM public.user_profiles
      WHERE id = auth.uid()
    )
  );

-- Триггер для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_equipment_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER equipment_updated_at
    BEFORE UPDATE ON public.equipment
    FOR EACH ROW
    EXECUTE FUNCTION update_equipment_updated_at();

-- Добавление тестовых данных (опционально)
INSERT INTO public.equipment (
    company_id,
    site_id,
    name,
    manufacturer,
    model,
    modification,
    serial_number,
    location,
    address,
    status,
    description
) VALUES (
    (SELECT id FROM public.companies LIMIT 1), -- первая доступная компания
    (SELECT id FROM public.sites LIMIT 1),     -- первая доступная площадка
    'Уборочная машина №1',
    'Gadlee',
    'GT30',
    null,
    'GT30-2024-001',
    'Главный офис',
    'г. Москва, ул. Примерная, д. 1',
    'active',
    'Основная уборочная машина для офисных помещений'
);
