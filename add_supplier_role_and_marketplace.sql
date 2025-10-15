-- Миграция: Добавление роли поставщика и маркетплейса
-- Дата: 2025-01-05

BEGIN;

-- 1. Добавляем новую роль "supplier" в enum (если используется enum)
-- Если роли хранятся как TEXT, этот шаг можно пропустить
-- ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'supplier';

-- 2. Создаем таблицу поставщиков (suppliers)
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE UNIQUE,
    company_name TEXT NOT NULL,
    company_inn TEXT UNIQUE,
    company_description TEXT,
    logo_url TEXT,
    website TEXT,
    rating DECIMAL(3,2) DEFAULT 0.00,
    reviews_count INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Контактная информация
    contact_email TEXT,
    contact_phone TEXT,
    support_email TEXT,
    support_phone TEXT,
    
    -- Адрес и реквизиты
    legal_address TEXT,
    actual_address TEXT,
    bank_details JSONB,
    
    -- Документы верификации
    documents JSONB, -- {inn_scan, license, certificate, etc}
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID REFERENCES public.user_profiles(id),
    
    -- Настройки маркетплейса
    commission_rate DECIMAL(5,2) DEFAULT 5.00, -- Комиссия платформы %
    payment_terms TEXT, -- Условия оплаты
    delivery_terms TEXT, -- Условия доставки
    warranty_policy TEXT, -- Политика гарантии
    return_policy TEXT, -- Политика возврата
    
    -- Статистика
    total_sales DECIMAL(15,2) DEFAULT 0.00,
    total_orders INTEGER DEFAULT 0,
    active_products INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Создаем таблицу команды поставщика (supplier_team)
CREATE TABLE IF NOT EXISTS public.supplier_team (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    supplier_id UUID REFERENCES public.suppliers(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('engineer', 'manager', 'support')),
    specialization TEXT[], -- Специализации инженера
    is_active BOOLEAN DEFAULT TRUE,
    hired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(supplier_id, user_id)
);

-- 4. Создаем таблицу каталога продуктов поставщика (supplier_products)
CREATE TABLE IF NOT EXISTS public.supplier_products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    supplier_id UUID REFERENCES public.suppliers(id) ON DELETE CASCADE,
    
    -- Основная информация
    name TEXT NOT NULL,
    description TEXT,
    category TEXT, -- 'equipment', 'parts', 'service_package'
    subcategory TEXT,
    
    -- Для оборудования
    manufacturer TEXT,
    model TEXT,
    specifications JSONB,
    
    -- Для запчастей
    sku TEXT,
    part_number TEXT,
    compatible_models TEXT[], -- Совместимые модели
    
    -- Цены и наличие
    base_price DECIMAL(15,2) NOT NULL,
    currency TEXT DEFAULT 'RUB',
    in_stock BOOLEAN DEFAULT TRUE,
    stock_quantity INTEGER,
    min_order_quantity INTEGER DEFAULT 1,
    
    -- Медиа
    images TEXT[],
    videos TEXT[],
    documents TEXT[], -- Инструкции, сертификаты
    
    -- SEO и маркетинг
    tags TEXT[],
    is_featured BOOLEAN DEFAULT FALSE,
    is_bestseller BOOLEAN DEFAULT FALSE,
    discount_percent DECIMAL(5,2) DEFAULT 0.00,
    
    -- Статистика
    views_count INTEGER DEFAULT 0,
    orders_count INTEGER DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0.00,
    reviews_count INTEGER DEFAULT 0,
    
    -- Статус
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'inactive', 'archived')),
    published_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Создаем таблицу индивидуальных прайсов для клиентов (client_price_overrides)
CREATE TABLE IF NOT EXISTS public.client_price_overrides (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    supplier_id UUID REFERENCES public.suppliers(id) ON DELETE CASCADE,
    client_company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.supplier_products(id) ON DELETE CASCADE,
    
    -- Индивидуальная цена
    special_price DECIMAL(15,2) NOT NULL,
    discount_percent DECIMAL(5,2),
    
    -- Период действия
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_to TIMESTAMP WITH TIME ZONE,
    
    -- Условия
    min_quantity INTEGER DEFAULT 1,
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.user_profiles(id),
    
    UNIQUE(supplier_id, client_company_id, product_id)
);

-- 6. Создаем таблицу заказов из магазина (marketplace_orders)
CREATE TABLE IF NOT EXISTS public.marketplace_orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_number TEXT UNIQUE NOT NULL,
    
    -- Участники
    client_company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    client_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
    
    -- Финансы
    subtotal DECIMAL(15,2) NOT NULL,
    discount DECIMAL(15,2) DEFAULT 0.00,
    tax DECIMAL(15,2) DEFAULT 0.00,
    delivery_cost DECIMAL(15,2) DEFAULT 0.00,
    total DECIMAL(15,2) NOT NULL,
    currency TEXT DEFAULT 'RUB',
    
    -- Статус
    status TEXT DEFAULT 'draft' CHECK (status IN (
        'draft', 'pending_payment', 'paid', 'processing', 
        'shipped', 'delivered', 'completed', 'cancelled', 'refunded'
    )),
    payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
    
    -- Доставка
    delivery_address TEXT,
    delivery_contact TEXT,
    delivery_phone TEXT,
    desired_delivery_date DATE,
    actual_delivery_date DATE,
    tracking_number TEXT,
    
    -- Примечания
    client_notes TEXT,
    internal_notes TEXT,
    
    -- Временные метки
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE,
    shipped_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE
);

-- 7. Создаем таблицу позиций заказа (marketplace_order_items)
CREATE TABLE IF NOT EXISTS public.marketplace_order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.marketplace_orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.supplier_products(id) ON DELETE SET NULL,
    
    -- Информация о продукте (на момент заказа)
    product_name TEXT NOT NULL,
    product_sku TEXT,
    product_description TEXT,
    
    -- Цены и количество
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    discount_percent DECIMAL(5,2) DEFAULT 0.00,
    line_total DECIMAL(15,2) NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Создаем таблицу отзывов на продукты (product_reviews)
CREATE TABLE IF NOT EXISTS public.product_reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES public.supplier_products(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    order_id UUID REFERENCES public.marketplace_orders(id) ON DELETE SET NULL,
    
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title TEXT,
    comment TEXT,
    pros TEXT,
    cons TEXT,
    
    images TEXT[],
    
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT FALSE,
    
    helpful_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(product_id, user_id, order_id)
);

-- 9. Индексы для оптимизации
CREATE INDEX IF NOT EXISTS idx_suppliers_user_id ON public.suppliers(user_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_verified ON public.suppliers(is_verified);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_active ON public.suppliers(is_active);
CREATE INDEX IF NOT EXISTS idx_supplier_team_supplier_id ON public.supplier_team(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_team_user_id ON public.supplier_team(user_id);
CREATE INDEX IF NOT EXISTS idx_supplier_products_supplier_id ON public.supplier_products(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_products_category ON public.supplier_products(category);
CREATE INDEX IF NOT EXISTS idx_supplier_products_status ON public.supplier_products(status);
CREATE INDEX IF NOT EXISTS idx_client_price_overrides_client ON public.client_price_overrides(client_company_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_client ON public.marketplace_orders(client_company_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_supplier ON public.marketplace_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_status ON public.marketplace_orders(status);
CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON public.product_reviews(product_id);

-- 10. RLS политики для suppliers
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

-- Супер-админ видит всех поставщиков
CREATE POLICY "Super admin can view all suppliers" ON public.suppliers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'superAdmin'
        )
    );

-- Поставщик видит только свою запись
CREATE POLICY "Suppliers can view own profile" ON public.suppliers
    FOR SELECT USING (user_id = auth.uid());

-- Поставщик может обновлять свою запись
CREATE POLICY "Suppliers can update own profile" ON public.suppliers
    FOR UPDATE USING (user_id = auth.uid());

-- Все могут видеть верифицированных и активных поставщиков
CREATE POLICY "Anyone can view verified suppliers" ON public.suppliers
    FOR SELECT USING (is_verified = TRUE AND is_active = TRUE);

-- 11. RLS политики для supplier_products
ALTER TABLE public.supplier_products ENABLE ROW LEVEL SECURITY;

-- Поставщик управляет своими продуктами
CREATE POLICY "Suppliers manage own products" ON public.supplier_products
    FOR ALL USING (
        supplier_id IN (
            SELECT id FROM public.suppliers WHERE user_id = auth.uid()
        )
    );

-- Все могут видеть активные продукты
CREATE POLICY "Anyone can view active products" ON public.supplier_products
    FOR SELECT USING (status = 'active');

-- 12. RLS политики для marketplace_orders
ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;

-- Клиент видит свои заказы
CREATE POLICY "Clients view own orders" ON public.marketplace_orders
    FOR SELECT USING (
        client_company_id IN (
            SELECT company_id FROM public.user_profiles WHERE id = auth.uid()
        )
    );

-- Поставщик видит заказы своих продуктов
CREATE POLICY "Suppliers view own orders" ON public.marketplace_orders
    FOR SELECT USING (
        supplier_id IN (
            SELECT id FROM public.suppliers WHERE user_id = auth.uid()
        )
    );

-- Супер-админ видит все заказы
CREATE POLICY "Super admin views all orders" ON public.marketplace_orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'superAdmin'
        )
    );

-- 13. Функция для обновления рейтинга продукта
CREATE OR REPLACE FUNCTION update_product_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.supplier_products
    SET 
        rating = (
            SELECT AVG(rating)::DECIMAL(3,2)
            FROM public.product_reviews
            WHERE product_id = NEW.product_id AND is_approved = TRUE
        ),
        reviews_count = (
            SELECT COUNT(*)
            FROM public.product_reviews
            WHERE product_id = NEW.product_id AND is_approved = TRUE
        ),
        updated_at = NOW()
    WHERE id = NEW.product_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_product_rating
AFTER INSERT OR UPDATE ON public.product_reviews
FOR EACH ROW
EXECUTE FUNCTION update_product_rating();

-- 14. Функция для генерации номера заказа
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('order_number_seq')::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS order_number_seq;

CREATE TRIGGER trigger_generate_order_number
BEFORE INSERT ON public.marketplace_orders
FOR EACH ROW
WHEN (NEW.order_number IS NULL)
EXECUTE FUNCTION generate_order_number();

-- 15. Добавляем поле supplier_id в таблицу user_profiles (если еще нет)
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_supplier_id ON public.user_profiles(supplier_id);

COMMIT;

-- Комментарии к таблицам
COMMENT ON TABLE public.suppliers IS 'Таблица поставщиков оборудования и запчастей';
COMMENT ON TABLE public.supplier_team IS 'Команда поставщика (инженеры, менеджеры)';
COMMENT ON TABLE public.supplier_products IS 'Каталог продуктов поставщиков';
COMMENT ON TABLE public.client_price_overrides IS 'Индивидуальные цены для клиентов';
COMMENT ON TABLE public.marketplace_orders IS 'Заказы из маркетплейса';
COMMENT ON TABLE public.marketplace_order_items IS 'Позиции заказов';
COMMENT ON TABLE public.product_reviews IS 'Отзывы на продукты';
