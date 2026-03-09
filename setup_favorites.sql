-- Таблица "Избранное" для Маркета
-- Запусти в Supabase SQL Editor
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    part_id UUID NOT NULL REFERENCES public.spare_parts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, part_id)
);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON public.favorites(user_id);
-- Отключаем RLS (используем кастомную аутентификацию)
ALTER TABLE public.favorites DISABLE ROW LEVEL SECURITY;