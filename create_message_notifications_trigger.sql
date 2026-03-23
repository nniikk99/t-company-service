-- ============================================================
-- ТРИГГЕР: Автоматические уведомления о новых сообщениях в чате
-- Запустить в Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- Функция триггера
CREATE OR REPLACE FUNCTION notify_new_request_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER  -- Важно! Запускается с правами создателя, обходя RLS
AS $$
DECLARE
  v_request        RECORD;
  v_short_id       TEXT;
  v_notif_title    TEXT;
  v_notif_message  TEXT;
  v_uid            TEXT;
  v_sender_id      TEXT;
  v_recipient_ids  TEXT[];
  v_admin_ids      TEXT[];
  v_staff_ids      TEXT[];
BEGIN
  -- Получаем данные заявки
  SELECT 
    sr.user_id,
    sr.assigned_engineer_id,
    sr.company_id,
    sr.company_inn,
    sr.supplier_id,
    sr.request_number,
    sr.id AS request_id
  INTO v_request
  FROM service_requests sr
  WHERE sr.id = NEW.request_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- Короткий ID заявки (6-значный номер или первые 5 символов)
  IF v_request.request_number IS NOT NULL THEN
    v_short_id := LPAD(v_request.request_number::TEXT, 6, '0');
  ELSE
    v_short_id := UPPER(SUBSTRING(NEW.request_id::TEXT, 1, 5));
  END IF;
  v_sender_id   := NEW.sender_id::TEXT;
  v_notif_title := 'Новое сообщение по заявке #' || v_short_id;
  v_notif_message := COALESCE(NEW.message, 'Вам прислали вложение в чат.');

  -- Собираем всех получателей в массив
  v_recipient_ids := ARRAY[]::TEXT[];

  -- 1. Автор заявки
  IF v_request.user_id IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || v_request.user_id::TEXT;
  END IF;

  -- 2. Назначенный инженер
  IF v_request.assigned_engineer_id IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || v_request.assigned_engineer_id::TEXT;
  END IF;

  -- 3. Администраторы
  SELECT ARRAY_AGG(id::TEXT) INTO v_admin_ids
  FROM user_profiles
  WHERE role IN ('superAdmin', 'administrator', 'super_admin');

  IF v_admin_ids IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || v_admin_ids;
  END IF;

  -- 4. Сотрудники компании клиента (ответственные и менеджеры площадок)
  IF v_request.company_id IS NOT NULL OR v_request.company_inn IS NOT NULL THEN
    SELECT ARRAY_AGG(id::TEXT) INTO v_staff_ids
    FROM user_profiles
    WHERE role IN ('companyResponsible', 'siteManager')
      AND (
        (v_request.company_id IS NOT NULL AND company_id = v_request.company_id)
        OR
        (v_request.company_inn IS NOT NULL AND company_inn = v_request.company_inn)
      );

    IF v_staff_ids IS NOT NULL THEN
      v_recipient_ids := v_recipient_ids || v_staff_ids;
    END IF;
  END IF;

  -- 5. Сотрудники поставщика
  IF v_request.supplier_id IS NOT NULL THEN
    SELECT ARRAY_AGG(id::TEXT) INTO v_staff_ids
    FROM user_profiles
    WHERE supplier_id = v_request.supplier_id;

    IF v_staff_ids IS NOT NULL THEN
      v_recipient_ids := v_recipient_ids || v_staff_ids;
    END IF;
  END IF;

  -- Создаём уведомление для каждого получателя (кроме отправителя)
  FOREACH v_uid IN ARRAY v_recipient_ids
  LOOP
    -- Пропускаем отправителя и дубли
    CONTINUE WHEN v_uid = v_sender_id;

    -- Вставляем уведомление (INSERT IGNORE при дублях та же секунда)
    INSERT INTO notifications (
      user_id,
      title,
      message,
      type,
      related_id,
      data,
      is_read,
      created_at
    ) VALUES (
      v_uid::UUID,
      v_notif_title,
      v_notif_message,
      'newMessage',
      NEW.request_id,
      jsonb_build_object('requestId', NEW.request_id::TEXT),
      FALSE,
      NOW()
    )
    ON CONFLICT DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Удаляем старый триггер если существует
DROP TRIGGER IF EXISTS trg_notify_new_request_message ON request_messages;

-- Создаём триггер
CREATE TRIGGER trg_notify_new_request_message
  AFTER INSERT ON request_messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_request_message();

-- Проверка: триггер создан
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'trg_notify_new_request_message';
