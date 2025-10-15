# 🚀 Быстрая настройка Supabase

## ✅ Ваши ключи уже добавлены в код!

Ваши ключи Supabase уже настроены в `lib/config/supabase_config.dart`:
- **URL**: `https://kwunhuzfnjpcoeusnxzy.supabase.co`
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- **Service Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

## 📋 Следующие шаги:

### 1. Настройте базу данных в Supabase

1. Откройте [ваш проект в Supabase](https://kwunhuzfnjpcoeusnxzy.supabase.co)
2. Перейдите в **SQL Editor** 
3. Выполните SQL из файла `initial_setup.sql`:

```sql
-- Создаем таблицу компаний
CREATE TABLE IF NOT EXISTS companies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Создаем тестовую компанию
INSERT INTO companies (name, description, contact_email) VALUES 
('ООО "Тест Компания"', 'Первая тестовая компания для разработки', 'test@company.ru')
ON CONFLICT DO NOTHING;

-- Включаем RLS и создаем политики доступа
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow read access" ON companies FOR SELECT USING (true);
CREATE POLICY "Allow insert access" ON companies FOR INSERT WITH CHECK (true);
```

### 2. Протестируйте подключение

1. Запустите приложение: `flutter run -d chrome --web-port=5171`
2. На экране авторизации нажмите **"🔧 Тест Supabase подключения"**
3. Проверьте статус подключения
4. Нажмите **"Создать тестовую компанию"** для проверки записи в БД

### 3. Создайте полную схему (опционально)

Для полной функциональности выполните весь `supabase_schema.sql`:

1. В Supabase SQL Editor
2. Скопируйте содержимое `supabase_schema.sql` 
3. Выполните запрос

Это создаст все таблицы:
- `companies` - компании
- `sites` - площадки  
- `user_profiles` - профили пользователей
- `equipment` - оборудование
- `service_requests` - сервисные заявки
- `parts_requests` - заявки на запчасти
- `notifications` - уведомления

## 🔧 Что уже готово:

### ✅ Интеграция Supabase:
- Подключение к вашей БД
- Сервисы для работы с данными
- Realtime подписки
- Аутентификация

### ✅ Исправлены ошибки:
- Все `clientId` заменены на `companyId`
- Модель User обновлена под Supabase
- Добавлена поддержка company join'ов

### ✅ Тестирование:
- Экран проверки подключения
- Создание тестовых данных
- Проверка статуса соединения

## 🚀 Запуск:

```bash
flutter run -d chrome --web-port=5171
```

Откроется: `http://localhost:5171`

1. Нажмите **"🔧 Тест Supabase подключения"**
2. Проверьте статус: должен показать "Подключение успешно!"
3. Создайте тестовую компанию
4. Вернитесь и войдите как обычно (демо данные)

## 🎯 Следующие шаги:

После успешного подключения можно:

1. **Мигрировать данные** из StorageService в Supabase
2. **Добавить реальную аутентификацию** через email/password
3. **Создать формы** для добавления компаний и оборудования
4. **Подключить Telegram Bot API** для уведомлений

**Все готово к работе! 🎉**
