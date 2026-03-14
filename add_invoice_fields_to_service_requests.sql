-- Скрипт для добавления полей под статус Ждет счет и Ждет оплату
DO $$ 
BEGIN 
    -- 1. Ссылка на счет документации / PDF
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'invoice_url') THEN
        ALTER TABLE service_requests ADD COLUMN invoice_url TEXT;
    END IF;

    -- 2. Сумма счета к оплате
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'invoice_amount') THEN
        ALTER TABLE service_requests ADD COLUMN invoice_amount NUMERIC(10,2);
    END IF;

    -- 3. Срок оплаты (необязательно, но полезно)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'service_requests' AND column_name = 'payment_due_date') THEN
        ALTER TABLE service_requests ADD COLUMN payment_due_date TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Опционально: Оповещаем PostgREST о структурных изменениях
    NOTIFY pgrst, 'reload schema';
END $$;
