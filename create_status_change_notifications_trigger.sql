-- ════════════════════════════════════════════════════════════════
-- ОБНОВЛЁННЫЙ ТРИГГЕР: Уведомления об изменении статуса заявки
-- ИСПРАВЛЕНИЕ: убран auth.uid() — он возвращает NULL в триггерах
-- Запустить в Supabase SQL Editor ПОЛНОСТЬЮ (всё сразу)
-- ════════════════════════════════════════════════════════════════

-- Функция перевода статуса на русский
CREATE OR REPLACE FUNCTION get_request_status_name(status TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN CASE status
    WHEN 'draft'                THEN 'Черновик'
    WHEN 'pending'              THEN 'Ожидает согласования'
    WHEN 'approved'             THEN 'Одобрена'
    WHEN 'rejected'             THEN 'Отклонена'
    WHEN 'inProgress'           THEN 'В работе'
    WHEN 'waitingForAcceptance' THEN 'Ожидает приёмки'
    WHEN 'waitingForInvoice'    THEN 'Ожидает счёт'
    WHEN 'waitingForPayment'    THEN 'Ожидает оплату'
    WHEN 'completed'            THEN 'Закрыта'
    WHEN 'cancelled'            THEN 'Отменена'
    ELSE status
  END;
END;
$$;

-- Функция перевода роли на русский
CREATE OR REPLACE FUNCTION get_role_display_name(p_role TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN CASE p_role
    WHEN 'administrator'     THEN 'Администратор'
    WHEN 'superAdmin'        THEN 'Администратор'
    WHEN 'super_admin'       THEN 'Администратор'
    WHEN 'engineer'          THEN 'Инженер'
    WHEN 'siteManager'       THEN 'Менеджер площадки'
    WHEN 'companyResponsible'THEN 'Ответственное лицо'
    WHEN 'supplier'          THEN 'Поставщик'
    WHEN 'operatorPM'        THEN 'Оператор'
    ELSE                          'Сотрудник'
  END;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- Основная функция триггера (БЕЗ auth.uid())
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_request_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_status_name    TEXT;
  v_short_id       TEXT;
  v_site_address   TEXT;
  v_changed_at_str TEXT;
  v_notif_title    TEXT;
  v_notif_message  TEXT;
  v_uid            TEXT;
  v_recipient_ids  TEXT[];
  v_tmp_ids        TEXT[];
BEGIN
  -- Пропускаем если статус не изменился
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- Русский статус
  v_status_name := get_request_status_name(NEW.status::TEXT);

  -- Короткий ID
  v_short_id := UPPER(LEFT(NEW.id::TEXT, 8));

  -- Адрес площадки
  SELECT COALESCE(s.address, s.name, 'не указан')
    INTO v_site_address
    FROM sites s
   WHERE s.id = NEW.site_id;

  v_site_address := COALESCE(v_site_address, 'не указан');

  -- Московское время
  v_changed_at_str := TO_CHAR(
    NOW() AT TIME ZONE 'Europe/Moscow',
    'DD.MM.YYYY HH24:MI'
  );

  -- Текст уведомления
  -- (кто изменил — определяем по инженеру/автору/роли, без auth.uid())
  v_notif_title   := 'Статус заявки #' || v_short_id || ' изменён';
  v_notif_message :=
      'Статус изменён на «' || v_status_name || '»' ||
      E'\n' || '📋 Заявка: #' || v_short_id ||
      E'\n' || '📍 Площадка: ' || v_site_address ||
      E'\n' || '🕐 ' || v_changed_at_str;

  -- ─── Собираем всех получателей ───────────────
  v_recipient_ids := ARRAY[]::TEXT[];

  -- Автор заявки
  IF NEW.user_id IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || ARRAY[NEW.user_id::TEXT];
  END IF;

  -- Инженер
  IF NEW.assigned_engineer_id IS NOT NULL THEN
    v_recipient_ids := v_recipient_ids || ARRAY[NEW.assigned_engineer_id::TEXT];
  END IF;

  -- Администраторы
  BEGIN
    SELECT ARRAY_AGG(id::TEXT) INTO v_tmp_ids
    FROM user_profiles
    WHERE role IN ('superAdmin', 'administrator', 'super_admin');
    IF v_tmp_ids IS NOT NULL THEN
      v_recipient_ids := v_recipient_ids || v_tmp_ids;
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  -- Компания клиента (ответственные + менеджеры площадок)
  IF NEW.company_id IS NOT NULL OR NEW.company_inn IS NOT NULL THEN
    BEGIN
      SELECT ARRAY_AGG(up.id::TEXT) INTO v_tmp_ids
      FROM user_profiles up
      WHERE up.role IN ('companyResponsible', 'siteManager')
        AND (
          (NEW.company_id  IS NOT NULL AND up.company_id  = NEW.company_id)
          OR
          (NEW.company_inn IS NOT NULL AND up.company_inn = NEW.company_inn)
        );
      IF v_tmp_ids IS NOT NULL THEN
        v_recipient_ids := v_recipient_ids || v_tmp_ids;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  END IF;

  -- Сотрудники поставщика
  IF NEW.supplier_id IS NOT NULL THEN
    BEGIN
      SELECT ARRAY_AGG(up.id::TEXT) INTO v_tmp_ids
      FROM user_profiles up
      WHERE up.supplier_id = NEW.supplier_id;
      IF v_tmp_ids IS NOT NULL THEN
        v_recipient_ids := v_recipient_ids || v_tmp_ids;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  END IF;

  -- Дедупликация массива
  SELECT ARRAY_AGG(DISTINCT uid) INTO v_recipient_ids
  FROM UNNEST(v_recipient_ids) AS uid;

  -- ─── Создаём уведомления ─────────────────────
  IF v_recipient_ids IS NOT NULL THEN
    FOREACH v_uid IN ARRAY v_recipient_ids
    LOOP
      BEGIN
        INSERT INTO notifications (
          user_id, title, message, type, related_id, data, is_read, created_at
        ) VALUES (
          v_uid::UUID,
          v_notif_title,
          v_notif_message,
          'requestUpdate',
          NEW.id,
          jsonb_build_object(
            'requestId', NEW.id::TEXT,
            'newStatus', NEW.status::TEXT,
            'oldStatus', OLD.status::TEXT,
            'siteAddress', v_site_address
          ),
          FALSE,
          NOW()
        );
      EXCEPTION WHEN OTHERS THEN
        -- Не прерываем триггер из-за одного сбойного пользователя
        RAISE WARNING 'notify_request_status_change: failed for user %: %', v_uid, SQLERRM;
      END;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- Пересоздаём триггер
DROP TRIGGER IF EXISTS trg_notify_request_status_change ON service_requests;

CREATE TRIGGER trg_notify_request_status_change
  AFTER UPDATE OF status ON service_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_request_status_change();

-- ─── Проверка: триггеры активны? ─────────────────
SELECT tgname,
       CASE tgenabled
         WHEN 'O' THEN '✅ Включён (Origin)'
         WHEN 'D' THEN '❌ Отключён'
         WHEN 'A' THEN '✅ Включён (Always)'
         ELSE tgenabled::TEXT
       END AS status
FROM pg_trigger
WHERE tgname IN (
  'trg_notify_request_status_change',
  'trg_notify_new_request_message'
);

-- ─── ТЕСТ: Вручную вставить тестовое уведомление ─
-- (раскомментируйте и замените UUID на реальный user_id для проверки)
-- INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
-- VALUES (
--   'ВАШ-USER-ID-ЗДЕСЬ'::UUID,
--   'Тест триггера',
--   'Если видите это — вставка в notifications работает',
--   'systemAlert', FALSE, NOW()
-- );
