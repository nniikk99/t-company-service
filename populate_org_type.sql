-- Миграция: Заполнение org_type для существующих компаний
-- Дата: 2025-10-15
-- Описание: Устанавливаем дефолтное значение 'customer' для всех компаний без org_type

BEGIN;

-- Заполняем org_type для существующих компаний
-- По умолчанию все компании считаются заказчиками
UPDATE public.companies 
SET org_type = 'customer' 
WHERE org_type IS NULL;

-- Можно вручную обновить конкретные компании, если известны поставщики:
-- UPDATE public.companies SET org_type = 'supplier' WHERE company_inn = '1234567890';
-- UPDATE public.companies SET org_type = 'service_partner' WHERE company_inn = '0987654321';

COMMIT;

