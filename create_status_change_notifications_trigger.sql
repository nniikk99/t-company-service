-- ============================================================
-- ТРИГГЕР: Уведомления об изменении статуса заявки
-- Запустить в Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- Вспомогательная функция: перевод статуса в русский
CREATE OR REPLACE FUNCTION get_request_status_name(status TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  RETURN CASE status
    WHEN 'draft'                 THEN 'Черновик'
    WHEN 'pending'               THEN 'Ожидает согласования'
    WHEN 'approved'              THEN 'Одобрена'
    WHEN 'rejected'              THEN 'Отклонена'
    WHEN 'inProgress'            THEN 'В работе'
    WHEN 'waitingForAcceptance'  THEN 'Ожидает приёмки'
    WHEN 'waitingForInvoice'     THEN 'Ожидает счёт'
    WHEN 'waitingForPayment'     THEN 'Ожидает оплату'
    WHEN 'completed'             THEN 'Закрыта'
    WHEN 'cancelled'             THEN 'Отменена'
    ELSE status
  END;
END;
$$;

-- Вспомогательная функция: роль на русском (для уведомлений)
CREATE OR REPLACE FUNCTION get_role_display_name(role TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  RETURN CASE role
    WHEN 'administrator'        THEN 'Администратор'
    WHEN 'superAdmin'           THEN 'Администратор'
    WHEN 'super_admin'          THEN 'Администратор'
    WHEN 'engineer'             THEN 'Инженер'
    WHEN 'siteManager'          THEN 'Менеджер площадки'
    WHEN 'companyResponsible'   THEN 'Ответственное лицо'
    WHEN 'supplier'             THEN 'Поставщик'
    WHEN 'operatorPM'           THEN 'Оператор'
    ELSE 'Сотрудник'
  END;
END;
$$;

-- ────────────────────────────────────────────
-- Основная функция триггера
-- ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_request_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_changer_id     TEXT;
  v_changer_role   TEXT;
  v_changer_name   TEXT;
  v_actor_label    TEXT;
  v_status_name    TEXT;
  v_short_id       TEXT;
  v_site_address   TEXT;
  v_changed_at_str TEXT;
  v_notif_title    TEXT;
  v_notif_message  TEXT;
  v_uid            TEXT;
  v_recipient_ids  TEXT[];
  v_admin_ids      TEXT[];
  v_staff_ids      TEXT[];
BEGIN
  -- Пропускаем если статус не изменился
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Кто изменил: auth.uid() – текущий пользователь Supabase
  v_changer_id := auth.uid()::TEXT;

  -- Получаем роль и имя изменившего
  SELECT role, first_name, last_name
  INTO   v_changer_role, v_changer_name, v_uid   -- v_uid – временная переменная
  FROM   user_profiles
  WHERE  id::TEXT = v_changer_id;

  -- Формируем метку исполнителя
  -- Для администраторов скрываем ФИО, показываем только роль
  IF v_changer_role IN ('administrator', 'superAdmin', 'super_admin') THEN
    v_actor_label := 'Администратор';
  ELSE
    v_actor_label := COALESCE(
      get_role_display_name(v_changer_role),
      'Сотрудник'
    );
  END IF;

  -- Русское название нового статуса
  v_status_name := get_request_status_name(NEW.status::TEXT);

  -- Короткий ID заявки
  v_short_id := UPPER(SUBSTRING(NEW.id::TEXT, 1, 8));

  -- Адрес площадки
  SELECT COALESCE(s.address, s.name, 'не указан')
  INTO   v_site_address
  FROM   sites s
  WHERE  s.id = NEW.site_id;

  IF v_site_address IS NULL THEN
    v_site_address := 'не указан';
  END IF;

  -- Время изменения (московское UTC+3)
  v_changed_at_str := TO_CHAR(
    NOW() AT TIME ZONE 'Europe/Moscow',
    'DD.MM.YYYY HH24:MI'
  );

  -- Заголовок и текст уведомления
  v_notif_title   := 'Статус заявки #' || v_short_id || ' изменён';
  v_notif_message := v_actor_label
    || ' изменил(а) статус на «' || v_status_name || '»'
    || E'\n' || '📋 Заявка: #' || v_short_id
    || E'\n' || '📍 Площадка: ' || v_site_address
    || E'\n' || '🕐 ' || v_changed_at_str;

  -- ─── Собираем получателей ───────────────────
  v_recipient_ids := ARRAY[]::TEXT[];

  -- 1. Автор заявки
  IF NEW.user_id IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || NEW.user_id::TEXT;
  END IF;

  -- 2. Назначенный инженер
  IF NEW.assigned_engineer_id IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || NEW.assigned_engineer_id::TEXT;
  END IF;

  -- 3. Администраторы
  SELECT ARRAY_AGG(id::TEXT) INTO v_admin_ids
  FROM   user_profiles
  WHERE  role IN ('superAdmin', 'administrator', 'super_admin');

  IF v_admin_ids IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || v_admin_ids;
  END IF;

  -- 4. Сотрудники компании клиента
  IF NEW.company_id IS NOT NULL OR NEW.company_inn IS NOT NULL THEN
    SELECT ARRAY_AGG(id::TEXT) INTO v_staff_ids
    FROM   user_profiles
    WHERE  role IN ('companyResponsible', 'siteManager')
      AND (
        (NEW.company_id  IS NOT NULL AND company_id  = NEW.company_id)
        OR
        (NEW.company_inn IS NOT NULL AND company_inn = NEW.company_inn)
      );

    IF v_staff_ids IS NOT NULL THEN
      v_recipient_ids := v_recipient_ids || v_staff_ids;
    END IF;
  END IF;

  -- 5. Сотрудники поставщика
  IF NEW.supplier_id IS NOT NULL THEN
    SELECT ARRAY_AGG(id::TEXT) INTO v_staff_ids
    FROM   user_profiles
    WHERE  supplier_id = NEW.supplier_id;

    IF v_staff_ids IS NOT NULL THEN
      v_recipient_ids := v_recipient_ids || v_staff_ids;
    END IF;
  END IF;

  -- ─── Создаём уведомления ────────────────────
  FOREACH v_uid IN ARRAY v_recipient_ids
  LOOP
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
      'requestUpdate',
      NEW.id,
      jsonb_build_object(
        'requestId',   NEW.id::TEXT,
        'newStatus',   NEW.status::TEXT,
        'changerRole', v_changer_role,
        'siteAddress', v_site_address
      ),
      FALSE,
      NOW()
    )
    ON CONFLICT DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Удаляем старый триггер если существует
DROP TRIGGER IF EXISTS trg_notify_request_status_change ON service_requests;

-- Создаём триггер (AFTER UPDATE для фиксации финального состояния)
CREATE TRIGGER trg_notify_request_status_change
  AFTER UPDATE OF status ON service_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_request_status_change();

-- Проверка
SELECT tgname, tgenabled
FROM   pg_trigger
WHERE  tgname IN (
  'trg_notify_request_status_change',
  'trg_notify_new_request_message'
);
