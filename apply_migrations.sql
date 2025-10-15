-- ПРИМЕНЕНИЕ МИГРАЦИЙ: Добавление org_type
-- Дата: 2025-10-15
-- 
-- ВНИМАНИЕ: Выполняйте этот файл в Supabase SQL Editor
-- Все миграции объединены в одном файле для удобства
--
-- ========================================
-- ШАГ 1: Добавление поля org_type
-- ========================================

BEGIN;

-- Добавляем столбец org_type в таблицу companies
ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS org_type TEXT CHECK (org_type IN ('customer', 'supplier', 'service_partner'));

-- Индекс для фильтрации по типу организации
CREATE INDEX IF NOT EXISTS idx_companies_org_type ON public.companies(org_type);

-- Комментарий к столбцу
COMMENT ON COLUMN public.companies.org_type IS 'Тип организации: customer (заказчик), supplier (поставщик), service_partner (сервисный партнер)';

COMMIT;

-- ========================================
-- ШАГ 2: Заполнение существующих компаний
-- ========================================

BEGIN;

-- Заполняем org_type для существующих компаний
-- По умолчанию все компании считаются заказчиками
UPDATE public.companies 
SET org_type = 'customer' 
WHERE org_type IS NULL;

-- ОПЦИОНАЛЬНО: Можно вручную обновить конкретные компании, если известны поставщики
-- Раскомментируйте и измените на нужные ИНН:
-- UPDATE public.companies SET org_type = 'supplier' WHERE company_inn = '1234567890';
-- UPDATE public.companies SET org_type = 'service_partner' WHERE company_inn = '0987654321';

COMMIT;

-- ========================================
-- ШАГ 3: Обновление схемы заявок и триггера
-- ========================================

BEGIN;

-- Добавляем поле org_type в таблицу company_requests
ALTER TABLE public.company_requests 
ADD COLUMN IF NOT EXISTS org_type TEXT 
DEFAULT 'customer'
CHECK (org_type IN ('customer', 'supplier', 'service_partner'));

-- Комментарий к столбцу
COMMENT ON COLUMN public.company_requests.org_type IS 'Тип организации: customer (заказчик), supplier (поставщик), service_partner (сервисный партнер)';

-- Обновляем функцию создания компании из заявки
CREATE OR REPLACE FUNCTION create_company_from_request()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
BEGIN
    -- Если заявка одобрена, создаем компанию
    IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
        -- Создаем компанию с org_type из заявки
        INSERT INTO companies (
            name, 
            company_inn, 
            description, 
            contact_email, 
            contact_phone, 
            address,
            org_type
        )
        VALUES (
            NEW.company_name, 
            NEW.company_inn, 
            'Создано из заявки пользователя', 
            NEW.company_email, 
            NEW.company_phone, 
            NEW.company_address,
            COALESCE(NEW.org_type, 'customer')
        )
        RETURNING id INTO new_company_id;
        
        -- Создаем связь пользователя с компанией
        INSERT INTO user_companies (user_id, company_id, company_inn, role, status, approved_by, approved_at)
        VALUES (NEW.user_id, new_company_id, NEW.company_inn, NEW.requested_role, 'approved', NEW.approved_by, NEW.approved_at);
        
        -- Обновляем профиль пользователя с новой компанией (если это первая компания)
        UPDATE user_profiles 
        SET company_id = new_company_id, company_inn = NEW.company_inn
        WHERE id = NEW.user_id AND company_id IS NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Пересоздаем триггер (если уже существует)
DROP TRIGGER IF EXISTS create_company_from_request_trigger ON company_requests;
CREATE TRIGGER create_company_from_request_trigger
    AFTER UPDATE ON company_requests
    FOR EACH ROW EXECUTE FUNCTION create_company_from_request();

COMMIT;

-- ========================================
-- ПРОВЕРКА РЕЗУЛЬТАТОВ
-- ========================================

-- Посмотреть структуру таблицы companies
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'companies' AND column_name = 'org_type';

-- Посмотреть структуру таблицы company_requests
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'company_requests' AND column_name = 'org_type';

-- Посмотреть количество компаний по типам
SELECT 
    org_type,
    COUNT(*) as count
FROM companies
GROUP BY org_type
ORDER BY count DESC;

-- Посмотреть первые 5 компаний с их типами
SELECT id, name, company_inn, org_type, created_at
FROM companies
ORDER BY created_at DESC
LIMIT 5;

-- ========================================
-- ГОТОВО!
-- ========================================
-- Миграции успешно применены.
-- Теперь можно развернуть обновлённый код приложения.

