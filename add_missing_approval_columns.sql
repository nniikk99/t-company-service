-- Миграция: Добавление недостающих полей подтверждения в service_requests
DO $$ 
BEGIN 
    -- Дата одобрения/назначения
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'approved_at') THEN
        ALTER TABLE public.service_requests ADD COLUMN approved_at TIMESTAMPTZ;
    END IF;

    -- Имя одобрившего (текстовое поле для таймлайна)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'approved_by') THEN
        ALTER TABLE public.service_requests ADD COLUMN approved_by TEXT;
    END IF;

    -- ID одобрившего (ссылка на пользователя)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'approved_by_user_id') THEN
        ALTER TABLE public.service_requests ADD COLUMN approved_by_user_id UUID REFERENCES users(id);
    END IF;

    -- Перезагрузка схемы PostgREST
    NOTIFY pgrst, 'reload schema';
END $$;
