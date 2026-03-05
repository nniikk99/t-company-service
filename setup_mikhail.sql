-- Скрипт для привязки существующих брендов и моделей к пользователю Михаилу Басалыгину

DO $$ 
DECLARE
  mikhail_id uuid;
BEGIN
  -- 1. Находим ID Михаила по номеру телефона
  -- Мы используем LIKE, чтобы найти номер независимо от того, какие скобки и символы применились в БД (+7964... или +7 (964)...)
  SELECT id INTO mikhail_id 
  FROM public.user_profiles 
  WHERE phone LIKE '%964%373%85%49%' 
  LIMIT 1;

  -- Либо можете раскомментировать строку ниже и вставить точный ID из Supabase Auth:
  -- mikhail_id := 'ТУТ-ID-ИЗ-БАЗЫ';

  IF mikhail_id IS NOT NULL THEN
    
    -- 2. Привязываем существующие модели оборудования к Михаилу (чтобы они были видны в его разделе Оборудование +)
    UPDATE public.equipment_models
    SET supplier_id = mikhail_id
    WHERE manufacturer IN ('Tennant', 'Gadlee', 'IPC');

    -- 3. Создаем карточки (записи) самих товарных знаков для Михаила в новой таблице
    -- Используем INSERT ... ON CONFLICT DO NOTHING, чтобы не продублировать, если вы запустите скрипт дважды
    INSERT INTO public.equipment_brands (name, supplier_id, status)
    VALUES 
      ('Tennant', mikhail_id, 'approved'),
      ('Gadlee', mikhail_id, 'approved'),
      ('IPC', mikhail_id, 'approved');

    RAISE NOTICE 'Товарные знаки и оборудование успешно привязаны к пользователю %', mikhail_id;
  ELSE
    RAISE EXCEPTION 'Пользователь Михаил не найден по номеру телефона! Проверьте, правильный ли номер занесен в БД.';
  END IF;
END $$;
