-- Запусти этот скрипт в Supabase SQL Editor
-- Если таблицы уже созданы — ничего не сломается (IF NOT EXISTS)
-- ================================
-- 1. ТАБЛИЦА ЗАПЧАСТЕЙ (spare_parts)
-- ================================
CREATE TABLE IF NOT EXISTS public.spare_parts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    article TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    category TEXT NOT NULL CHECK (
        category IN (
            'Расходные материалы',
            'Основные узлы',
            'Части корпуса',
            'Аксессуары',
            'Другое'
        )
    ),
    images TEXT [] DEFAULT '{}',
    compatible_models TEXT [] DEFAULT '{}',
    in_stock BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_spare_parts_supplier ON public.spare_parts(supplier_id);
CREATE INDEX IF NOT EXISTS idx_spare_parts_category ON public.spare_parts(category);
-- ================================
-- 2. ТАБЛИЦА КОРЗИНЫ (cart_items)
-- ================================
CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    part_id UUID NOT NULL REFERENCES public.spare_parts(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, part_id)
);
CREATE INDEX IF NOT EXISTS idx_cart_items_user ON public.cart_items(user_id);
-- ================================
-- 3. ТАБЛИЦА ЗАКАЗОВ (part_orders)
-- ================================
CREATE TABLE IF NOT EXISTS public.part_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN (
            'pending',
            'processing',
            'shipped',
            'delivered',
            'cancelled'
        )
    ),
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_part_orders_client ON public.part_orders(client_id);
CREATE INDEX IF NOT EXISTS idx_part_orders_supplier ON public.part_orders(supplier_id);
-- ================================
-- 4. ПОЗИЦИИ ЗАКАЗА (part_order_items)
-- ================================
CREATE TABLE IF NOT EXISTS public.part_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.part_orders(id) ON DELETE CASCADE,
    part_id UUID NOT NULL REFERENCES public.spare_parts(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price_at_order NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_part_order_items_order ON public.part_order_items(order_id);
-- ================================
-- 5. RLS (включаем)
-- ================================
ALTER TABLE public.spare_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.part_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.part_order_items ENABLE ROW LEVEL SECURITY;
-- ================================
-- 6. ПОЛИТИКИ spare_parts
-- (DROP IF EXISTS чтобы не дублировать при повторном запуске)
-- ================================
DROP POLICY IF EXISTS "Anyone can view spare parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Suppliers can insert own parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Suppliers can update own parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Suppliers can delete own parts" ON public.spare_parts;
CREATE POLICY "Anyone can view spare parts" ON public.spare_parts FOR
SELECT USING (true);
CREATE POLICY "Suppliers can insert own parts" ON public.spare_parts FOR
INSERT WITH CHECK (auth.uid() = supplier_id);
CREATE POLICY "Suppliers can update own parts" ON public.spare_parts FOR
UPDATE USING (auth.uid() = supplier_id);
CREATE POLICY "Suppliers can delete own parts" ON public.spare_parts FOR DELETE USING (auth.uid() = supplier_id);
-- ================================
-- 7. ПОЛИТИКИ cart_items
-- ================================
DROP POLICY IF EXISTS "Users can view own cart" ON public.cart_items;
DROP POLICY IF EXISTS "Users can insert to own cart" ON public.cart_items;
DROP POLICY IF EXISTS "Users can update own cart" ON public.cart_items;
DROP POLICY IF EXISTS "Users can delete from own cart" ON public.cart_items;
CREATE POLICY "Users can view own cart" ON public.cart_items FOR
SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert to own cart" ON public.cart_items FOR
INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own cart" ON public.cart_items FOR
UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete from own cart" ON public.cart_items FOR DELETE USING (auth.uid() = user_id);
-- ================================
-- 8. ПОЛИТИКИ part_orders
-- ================================
DROP POLICY IF EXISTS "Users can view related orders" ON public.part_orders;
DROP POLICY IF EXISTS "Clients can create orders" ON public.part_orders;
DROP POLICY IF EXISTS "Related users can update orders" ON public.part_orders;
CREATE POLICY "Users can view related orders" ON public.part_orders FOR
SELECT USING (
        auth.uid() = client_id
        OR auth.uid() = supplier_id
        OR EXISTS (
            SELECT 1
            FROM user_profiles
            WHERE id = auth.uid()
                AND role IN ('superAdmin', 'administrator')
        )
    );
CREATE POLICY "Clients can create orders" ON public.part_orders FOR
INSERT WITH CHECK (auth.uid() = client_id);
CREATE POLICY "Related users can update orders" ON public.part_orders FOR
UPDATE USING (
        auth.uid() = client_id
        OR auth.uid() = supplier_id
    );
-- ================================
-- 9. ПОЛИТИКИ part_order_items
-- ================================
DROP POLICY IF EXISTS "Users can view related order items" ON public.part_order_items;
DROP POLICY IF EXISTS "Clients can insert order items" ON public.part_order_items;
CREATE POLICY "Users can view related order items" ON public.part_order_items FOR
SELECT USING (
        EXISTS (
            SELECT 1
            FROM part_orders
            WHERE part_orders.id = part_order_items.order_id
                AND (
                    part_orders.client_id = auth.uid()
                    OR part_orders.supplier_id = auth.uid()
                )
        )
        OR EXISTS (
            SELECT 1
            FROM user_profiles
            WHERE id = auth.uid()
                AND role IN ('superAdmin', 'administrator')
        )
    );
CREATE POLICY "Clients can insert order items" ON public.part_order_items FOR
INSERT WITH CHECK (
        EXISTS (
            SELECT 1
            FROM part_orders
            WHERE part_orders.id = part_order_items.order_id
                AND part_orders.client_id = auth.uid()
        )
    );