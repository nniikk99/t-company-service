-- Таблица для моделей оборудования от поставщиков
CREATE TABLE IF NOT EXISTS public.equipment_models (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supplier_id UUID REFERENCES public.users(id),
    manufacturer TEXT NOT NULL,
    model TEXT NOT NULL,
    image_url TEXT,
    specifications JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Комментарии к таблице
COMMENT ON TABLE public.equipment_models IS 'Модели оборудования, созданные поставщиками';

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_equipment_models_supplier_id ON public.equipment_models(supplier_id);
CREATE INDEX IF NOT EXISTS idx_equipment_models_manufacturer_model ON public.equipment_models(manufacturer, model);

-- Политики безопасности (RLS)
ALTER TABLE public.equipment_models ENABLE ROW LEVEL SECURITY;

-- Все могут просматривать модели
CREATE POLICY "All users can view equipment models" 
ON public.equipment_models FOR SELECT 
USING (true);

-- Только поставщики могут создавать свои модели
CREATE POLICY "Suppliers can insert their own models" 
ON public.equipment_models FOR INSERT 
WITH CHECK (
    auth.uid() = supplier_id 
    AND EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role = 'supplier'
    )
);

-- Только поставщики могут обновлять свои модели
CREATE POLICY "Suppliers can update their own models" 
ON public.equipment_models FOR UPDATE 
USING (auth.uid() = supplier_id);

-- Только поставщики или админы могут удалять модели
CREATE POLICY "Suppliers or admins can delete models" 
ON public.equipment_models FOR DELETE 
USING (
    auth.uid() = supplier_id 
    OR EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')
    )
);
