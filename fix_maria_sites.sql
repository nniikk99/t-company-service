DO $$ 
DECLARE
  maria_id uuid;
  new_company_id uuid;
  site_record record;
  assigned_sites uuid[] := '{}';
BEGIN
  -- 1. Находим Марию
  SELECT id, company_id INTO maria_id, new_company_id 
  FROM public.user_profiles 
  WHERE last_name = 'Петрова' AND first_name = 'Мария' LIMIT 1;

  -- 2. Ищем все площадки, которые привязаны к текущему оборудованию Марии
  FOR site_record IN 
    SELECT DISTINCT site_id FROM public.equipment WHERE company_id = new_company_id AND site_id IS NOT NULL
  LOOP
    -- 3. Обновляем company_id у самой площадки, привязывая её к новой компании
    -- Приводим типы к тексту (::text), чтобы избежать ошибки "text <> uuid"
    UPDATE public.sites
    SET company_id = new_company_id::text
    WHERE id = site_record.site_id AND (company_id IS NULL OR company_id::text != new_company_id::text);
    
    -- Собираем список площадок (проверяем, чтобы site_id можно было скастовать в uuid)
    assigned_sites := array_append(assigned_sites, site_record.site_id::uuid);
  END LOOP;

  -- 4. Выдаем Марии доступ ко всем её площадкам
  IF array_length(assigned_sites, 1) > 0 THEN
    UPDATE public.user_profiles
    SET assigned_site_ids = assigned_sites
    WHERE id = maria_id;
    
    RAISE NOTICE '✅ Площадки успешно восстановлены и привязаны к Марии! ID площадок: %', assigned_sites;
  ELSE
    RAISE NOTICE 'ℹ️ Площадки не найдены (вероятно, они были удалены вместе со старой компанией, либо у оборудования не было установлено площадок).';
  END IF;
END $$;
