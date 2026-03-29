-- Миграция: Расширенные реквизиты организации для формирования документов
DO $$ 
BEGIN 
    -- 1. Юридические реквизиты
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'kpp') THEN
        ALTER TABLE companies ADD COLUMN kpp VARCHAR(9);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'ogrn') THEN
        ALTER TABLE companies ADD COLUMN ogrn VARCHAR(15);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'org_form') THEN
        ALTER TABLE companies ADD COLUMN org_form TEXT; -- 'ИП', 'ООО', 'АО'
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'legal_address') THEN
        ALTER TABLE companies ADD COLUMN legal_address TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'city') THEN
        ALTER TABLE companies ADD COLUMN city TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'director_name') THEN
        ALTER TABLE companies ADD COLUMN director_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'director_basis') THEN
        ALTER TABLE companies ADD COLUMN director_basis TEXT; -- 'Устав', 'Доверенность'
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'registration_number') THEN
        ALTER TABLE companies ADD COLUMN registration_number TEXT;
    END IF;

    -- 2. Банковские реквизиты
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'bank_name') THEN
        ALTER TABLE companies ADD COLUMN bank_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'bik') THEN
        ALTER TABLE companies ADD COLUMN bik VARCHAR(9);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'checking_account') THEN
        ALTER TABLE companies ADD COLUMN checking_account VARCHAR(20);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'correspondent_account') THEN
        ALTER TABLE companies ADD COLUMN correspondent_account VARCHAR(20);
    END IF;

    -- 3. НДС и Документы (сканы)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'vat_included') THEN
        ALTER TABLE companies ADD COLUMN vat_included BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'signature_url') THEN
        ALTER TABLE companies ADD COLUMN signature_url TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'companies' AND column_name = 'stamp_url') THEN
        ALTER TABLE companies ADD COLUMN stamp_url TEXT;
    END IF;

    -- Обновляем схему в кэше PostgREST (если используется)
    NOTIFY pgrst, 'reload schema';
END $$;
