-- ИСПРАВЛЕНИЕ СХЕМЫ: Перенаправляем внешний ключ с users на user_profiles
BEGIN;

-- 1. Удаляем старый внешний ключ
ALTER TABLE IF EXISTS public.equipment_models 
DROP CONSTRAINT IF EXISTS equipment_models_supplier_id_fkey;

-- 2. Добавляем новый внешний ключ на правильную таблицу user_profiles
ALTER TABLE public.equipment_models
ADD CONSTRAINT equipment_models_supplier_id_fkey 
FOREIGN KEY (supplier_id) REFERENCES public.user_profiles(id) 
ON DELETE CASCADE;

-- 3. Также исправляем политики RLS, если они ссылаются на таблицу users
DROP POLICY IF EXISTS "Suppliers can insert their own models" ON public.equipment_models;
CREATE POLICY "Suppliers can insert their own models" 
ON public.equipment_models FOR INSERT 
WITH CHECK (
    auth.uid() = supplier_id 
    AND EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role = 'supplier'
    )
);

DROP POLICY IF EXISTS "Suppliers or admins can delete models" ON public.equipment_models;
CREATE POLICY "Suppliers or admins can delete models" 
ON public.equipment_models FOR DELETE 
USING (
    auth.uid() = supplier_id 
    OR EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role IN ('superAdmin', 'administrator')
    )
);

COMMIT;

-- После этого скрипта можно запускать fix_all_equipment_data.sql
