-- Обновление схемы оборудования для поддержки типов и даты покупки

-- Добавление колонки type (тип оборудования)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='equipment' AND column_name='type') THEN
        ALTER TABLE equipment ADD COLUMN type TEXT;
    END IF;
END $$;

-- Добавление колонки purchase_date (дата реализации)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='equipment' AND column_name='purchase_date') THEN
        ALTER TABLE equipment ADD COLUMN purchase_date TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- Комментарии к колонкам
COMMENT ON COLUMN equipment.type IS 'Тип оборудования (например, поломоечная машина)';
COMMENT ON COLUMN equipment.purchase_date IS 'Дата реализации (покупки/установки) оборудования';

-- Индексы для ускорения фильтрации
CREATE INDEX IF NOT EXISTS idx_equipment_type ON equipment(type);
