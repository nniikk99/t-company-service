-- 1. Удаляем ограничение, чтобы добавить роль 'supplier'
ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;

-- 2. Создаем новое ограничение с нужными ролями
ALTER TABLE public.user_profiles ADD CONSTRAINT user_profiles_role_check 
CHECK (role IN (
  'pendingApproval', 
  'operatorPM', 
  'engineer', 
  'siteManager', 
  'companyResponsible', 
  'supplier', 
  'administrator', 
  'superAdmin', 
  'admin', 
  'clientManager', 
  'clientResponsible', 
  'contactPerson'
));

-- 3. Создаем таблицу для товарных знаков
CREATE TABLE IF NOT EXISTS public.equipment_brands (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  supplier_id uuid REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  created_at timestamp with time zone DEFAULT now()
);

-- Настраиваем RLS для новой таблицы
ALTER TABLE public.equipment_brands ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Поставщики могут видеть и создавать свои бренды" ON public.equipment_brands
  FOR ALL USING (auth.uid() = supplier_id);

CREATE POLICY "Все могут видеть одобренные бренды" ON public.equipment_brands
  FOR SELECT USING (status = 'approved');

CREATE POLICY "Админы могут всё с брендами" ON public.equipment_brands
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role IN ('superAdmin', 'administrator')
    )
  );

-- Даем доступ анонимным пользователям к одобренным брендам (иногда полезно при регистрации оборудования)
CREATE POLICY "Anon read approved brands" ON public.equipment_brands
  FOR SELECT USING (status = 'approved');
