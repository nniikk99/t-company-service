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
-- 5. ОТКЛЮЧАЕМ RLS (как для user_profiles и companies)
-- Приложение использует кастомную авторизацию (anon key + password_hash)
-- auth.uid() всегда = NULL, поэтому RLS на основе auth.uid() не работает
-- ================================
ALTER TABLE public.spare_parts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.part_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.part_order_items DISABLE ROW LEVEL SECURITY;
-- Убираем все ранее созданные политики (на случай если они были созданы)
DROP POLICY IF EXISTS "Anyone can view spare parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Suppliers can insert own parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Suppliers can update own parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Suppliers can delete own parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Admins can manage all spare parts" ON public.spare_parts;
DROP POLICY IF EXISTS "Users can view own cart" ON public.cart_items;
DROP POLICY IF EXISTS "Users can insert to own cart" ON public.cart_items;
DROP POLICY IF EXISTS "Users can update own cart" ON public.cart_items;
DROP POLICY IF EXISTS "Users can delete from own cart" ON public.cart_items;
DROP POLICY IF EXISTS "Users can view related orders" ON public.part_orders;
DROP POLICY IF EXISTS "Clients can create orders" ON public.part_orders;
DROP POLICY IF EXISTS "Related users can update orders" ON public.part_orders;
DROP POLICY IF EXISTS "Users can view related order items" ON public.part_order_items;
DROP POLICY IF EXISTS "Clients can insert order items" ON public.part_order_items;