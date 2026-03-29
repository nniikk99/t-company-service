-- Миграция: Добавление полей для документов (Акты, Счета) в service_requests
DO $$ 
BEGIN 
    -- ID компании-исполнителя (выбирает администратор при формировании акта)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'executor_company_id') THEN
        ALTER TABLE service_requests ADD COLUMN executor_company_id UUID REFERENCES companies(id);
    END IF;

    -- Ссылка на сгенерированный PDF акта в Supabase Storage
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'act_url') THEN
        ALTER TABLE service_requests ADD COLUMN act_url TEXT;
    END IF;

    -- Номер акта (например, "АКТ-00123")
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'act_number') THEN
        ALTER TABLE service_requests ADD COLUMN act_number TEXT;
    END IF;

    -- Дата формирования акта
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'act_created_at') THEN
        ALTER TABLE service_requests ADD COLUMN act_created_at TIMESTAMPTZ;
    END IF;

    -- Номер договора (для указания в акте)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'contract_number') THEN
        ALTER TABLE service_requests ADD COLUMN contract_number TEXT;
    END IF;

    NOTIFY pgrst, 'reload schema';
END $$;
