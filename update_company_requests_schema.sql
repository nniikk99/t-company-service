-- Миграция: Добавление org_type в company_requests и обновление триггера
-- Дата: 2025-10-15
-- Описание: Расширяем функционал создания компаний с поддержкой типа организации

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

COMMIT;

