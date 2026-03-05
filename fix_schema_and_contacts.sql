-- Comprehensive Schema Fix for Service Requests and Equipment
-- Date: 2026-02-22
-- Version: 2.0 (Added company_id)

-- 1. FIX SERVICE_REQUESTS TABLE
DO $$ 
BEGIN 
    -- Add company_id column (CRITICAL FIX for createServiceRequest)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='service_requests' AND column_name='company_id') THEN
        ALTER TABLE service_requests ADD COLUMN company_id UUID REFERENCES companies(id) ON DELETE CASCADE;
    END IF;

    -- Add attachments column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='service_requests' AND column_name='attachments') THEN
        ALTER TABLE service_requests ADD COLUMN attachments TEXT[];
    END IF;

    -- Add estimated_cost column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='service_requests' AND column_name='estimated_cost') THEN
        ALTER TABLE service_requests ADD COLUMN estimated_cost NUMERIC(10,2);
    END IF;

    -- Add scheduled_at column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='service_requests' AND column_name='scheduled_at') THEN
        ALTER TABLE service_requests ADD COLUMN scheduled_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Add notes column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='service_requests' AND column_name='notes') THEN
        ALTER TABLE service_requests ADD COLUMN notes TEXT;
    END IF;
END $$;

-- 2. FIX EQUIPMENT TABLE
DO $$ 
BEGIN 
    -- Add site_manager_contact column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='equipment' AND column_name='site_manager_contact') THEN
        ALTER TABLE equipment ADD COLUMN site_manager_contact TEXT;
    END IF;

    -- Add operator_contact column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='equipment' AND column_name='operator_contact') THEN
        ALTER TABLE equipment ADD COLUMN operator_contact TEXT;
    END IF;
    
    -- Add company_inn column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='equipment' AND column_name='company_inn') THEN
        ALTER TABLE equipment ADD COLUMN company_inn TEXT;
    END IF;
END $$;

-- 3. UPDATE COMMENTS
COMMENT ON COLUMN service_requests.company_id IS 'ID компании, которой принадлежит заявка';
COMMENT ON COLUMN service_requests.attachments IS 'Ссылки на вложенные файлы (фото, документы)';
COMMENT ON COLUMN service_requests.estimated_cost IS 'Предварительная стоимость работ';
COMMENT ON COLUMN service_requests.scheduled_at IS 'Запланированная дата выполнения';
COMMENT ON COLUMN service_requests.notes IS 'Дополнительные примечания к заявке';
COMMENT ON COLUMN equipment.site_manager_contact IS 'Контактные данные менеджера площадки';
COMMENT ON COLUMN equipment.operator_contact IS 'Контактные данные оператора ПМ';

-- 4. REFRESH SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
