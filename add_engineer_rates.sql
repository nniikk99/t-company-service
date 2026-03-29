-- Добавляем поля тарификации инженеров в таблицу users
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS call_out_rate NUMERIC DEFAULT 5000,
ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC DEFAULT 1500;

-- Комментарии к колонкам
COMMENT ON COLUMN public.users.call_out_rate IS 'Фиксированная ставка за выезд инженера';
COMMENT ON COLUMN public.users.hourly_rate IS 'Почасовая ставка работы инженера на объекте';

-- Добавляем поля в заявки для фиксации условий оплаты и ставок
ALTER TABLE public.service_requests
ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'platform',
ADD COLUMN IF NOT EXISTS engineer_call_out_rate NUMERIC,
ADD COLUMN IF NOT EXISTS engineer_hourly_rate NUMERIC;

-- Ограничение для типа оплаты (platform, supplier, warranty)
ALTER TABLE public.service_requests
ADD CONSTRAINT check_payment_type CHECK (payment_type IN ('platform', 'supplier', 'warranty'));

-- Комментарии
COMMENT ON COLUMN public.service_requests.payment_type IS 'Тип оплаты: platform (через нас), supplier (напрямую поставщику), warranty (гарантия)';
COMMENT ON COLUMN public.service_requests.engineer_call_out_rate IS 'Зафиксированная ставка выезда инженера на момент назначения';
COMMENT ON COLUMN public.service_requests.engineer_hourly_rate IS 'Зафиксированная часовая ставка инженера на момент назначения';

-- Перезагрузка схемы PostgREST
NOTIFY pgrst, 'reload schema';
