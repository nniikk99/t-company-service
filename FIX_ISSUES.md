# 🔧 Исправление проблем в Telegram Mini App

## Проблема 1: Прокрутка всего приложения вместо страницы

**Решение:** CSS стили для контроля прокрутки в Telegram WebView добавлены в `web/index.html`.

---

## Проблема 2: Ошибка подключения к базе данных при создании площадок

**Ошибка:** `Load failed, uri=https://your-project-ref.supabase.co/rest/v1/sites?select=%2A`

### Что нужно сделать:

#### 1. Проверь существование таблицы `sites` в Supabase

Открой Supabase Dashboard:
- URL: https://supabase.com/dashboard/project/kwunhuzfnjpcoeusnxzy
- Таблица `sites` должна существовать

#### 2. Создай таблицу `sites` если её нет

```sql
CREATE TABLE IF NOT EXISTS sites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT,
  responsible_person TEXT,
  phone TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS политики
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view sites of their companies"
  ON sites FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_companies
      WHERE user_companies.user_id = auth.uid()
      AND user_companies.company_id = sites.company_id
    )
  );

CREATE POLICY "Admins can manage all sites"
  ON sites FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );
```

#### 3. Создай тестовую площадку для проверки

Используй SQL Editor в Supabase:

```sql
INSERT INTO sites (company_id, name, address, responsible_person, phone, email)
VALUES (
  '00000000-0000-0000-0000-000000000000', -- ID компании
  'Тестовая площадка',
  'Москва',
  'Иванов Иван Иванович',
  '+7 (999) 123-45-67',
  'test@example.com'
)
ON CONFLICT DO NOTHING;
```

#### 4. Проверь права доступа

В Supabase Dashboard:
- Authentication → Policies
- Убедись что RLS включен для таблицы `sites`
- Проверь политики доступа

#### 5. Проверь CORS в Supabase

В Authentication → URL Configuration добавь:
- `https://nniikk99.github.io`
- `https://web.telegram.org`
- `https://t.me`

---

## Как проверить что всё работает:

1. **Открой приложение в Telegram**
2. **Войди как админ**
3. **Открой управление площадками**
4. **Создай новую площадку**
5. **Ошибка должна исчезнуть**

---

## Если проблема остаётся:

1. Проверь логи Supabase в Dashboard → Logs
2. Проверь консоль браузера в Telegram (если возможно)
3. Убедись что RLS политики правильно настроены

