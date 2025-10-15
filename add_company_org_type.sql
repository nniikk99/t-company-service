-- Миграция: Добавление типа организации в companies
-- Дата: 2025-10-05

BEGIN;

-- Добавляем столбец org_type в таблицу companies
ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS org_type TEXT CHECK (org_type IN ('customer', 'supplier', 'service_partner'));

-- Индекс для фильтрации по типу организации
CREATE INDEX IF NOT EXISTS idx_companies_org_type ON public.companies(org_type);

-- Комментарий к столбцу
COMMENT ON COLUMN public.companies.org_type IS 'Тип организации: customer (заказчик), supplier (поставщик), service_partner (сервисный партнер)';

COMMIT;


