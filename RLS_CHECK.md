# 🔍 Диагностика RLS политик для таблицы sites

## Проверь RLS политики в Supabase Dashboard

### 1. Открой таблицу sites
- В левом меню выбери `sites`
- Переключись на вкладку "Definition" (внизу справа)

### 2. Проверь RLS статус
- Должно быть: `Row Level Security: Enabled`
- Если `Disabled` - включи RLS

### 3. Проверь политики доступа
Нажми кнопку "RLS policy" (рядом с Insert)

Должны быть политики:
```sql
-- Политика для просмотра площадок компании
CREATE POLICY "Users can view sites of their companies"
ON sites FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM user_companies
    WHERE user_companies.user_id = auth.uid()
    AND user_companies.company_id = sites.company_id
  )
);

-- Политика для админов
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

### 4. Если политик нет - создай их

В SQL Editor выполни:
```sql
-- Включить RLS
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

-- Политика для просмотра
CREATE POLICY "Users can view sites of their companies"
ON sites FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM user_companies
    WHERE user_companies.user_id = auth.uid()
    AND user_companies.company_id = sites.company_id
  )
);

-- Политика для создания/обновления
CREATE POLICY "Users can manage sites of their companies"
ON sites FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM user_companies
    WHERE user_companies.user_id = auth.uid()
    AND user_companies.company_id = sites.company_id
  )
);

-- Политика для админов (полный доступ)
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

### 5. Проверь CORS настройки

В Authentication → URL Configuration добавь:
- `https://nniikk99.github.io`
- `https://web.telegram.org`
- `https://t.me`

### 6. Тест подключения

После настройки политик:
1. Открой приложение в Telegram
2. Попробуй создать площадку
3. Ошибка должна исчезнуть

---

## Если проблема остаётся

Проверь логи в Supabase Dashboard → Logs → API Logs
Там будет точная ошибка с кодом.
