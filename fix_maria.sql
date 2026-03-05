DO $$ 
DECLARE
  maria_id uuid;
  gadlee_company_id uuid;
  existing_company_id uuid;
  c_inn text;
  c_name text;
  uc_exists boolean;
BEGIN
  -- 1. Ищем саму Марию Петрову
  SELECT id INTO maria_id FROM public.user_profiles 
  WHERE last_name = 'Петрова' AND first_name = 'Мария' LIMIT 1;
  
  IF maria_id IS NULL THEN
    RAISE EXCEPTION '❌ Ошибка! Мария Петрова не найдена!';
  END IF;

  -- 2. Смотрим, к какой компании привязано оборудование Gadlee
  SELECT company_id INTO gadlee_company_id FROM public.equipment
  WHERE manufacturer = 'Gadlee' AND company_id IS NOT NULL 
  LIMIT 1;

  -- 3. Проверяем, существует ли на самом деле эта компания в БД
  SELECT id, company_inn, name INTO existing_company_id, c_inn, c_name 
  FROM public.companies WHERE id = gadlee_company_id;

  IF existing_company_id IS NULL THEN
    -- Если компания была удалена, мы создаем новую
    c_inn := '1234567890';
    c_name := 'ТЦ Мария Петрова';
    
    INSERT INTO public.companies (name, company_inn, description)
    VALUES (c_name, c_inn, 'Восстановленная компания')
    RETURNING id INTO existing_company_id;

    -- И сразу переносим всё оборудование Гадли в новую компанию
    UPDATE public.equipment
    SET company_id = existing_company_id
    WHERE company_id = gadlee_company_id;
    
    RAISE NOTICE '⚠️ Старая компания была удалена. Создана новая и оборудование перенесено!';
  END IF;

  -- 4. Теперь безопасно привязываем Марию к рабочей компании 
  UPDATE public.user_profiles
  SET company_id = existing_company_id,
      company_inn = c_inn
  WHERE id = maria_id;

  -- 5. Проверяем, есть ли Мария в таблице user_companies
  SELECT EXISTS(
    SELECT 1 FROM public.user_companies 
    WHERE user_id = maria_id AND company_id = existing_company_id
  ) INTO uc_exists;

  -- И если нет, то создаем запись, ПРЕДОСТАВЛЯЯ все обязательные поля (ИНН и Название)
  IF NOT uc_exists THEN
    INSERT INTO public.user_companies (user_id, company_id, company_inn, company_name, role, status)
    VALUES (maria_id, existing_company_id, c_inn, c_name, 'companyResponsible', 'approved');
  END IF;

  RAISE NOTICE '✅ Успех! Мария Петрова привязана к компании (ID: %) и оборудование Gadlee теперь в ней!', existing_company_id;
END $$;
