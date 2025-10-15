# Настройка Supabase для T-Co Service

## 🚀 Быстрый старт

### 1. Создание проекта в Supabase

1. Перейдите на [supabase.com](https://supabase.com)
2. Нажмите "Start your project" → "New project"
3. Выберите организацию и создайте проект:
   - Name: `t-co-service`
   - Database Password: `ваш_безопасный_пароль`
   - Region: `Central EU (Frankfurt)` (или ближайший к вам)

### 2. Получение ключей API

После создания проекта:

1. Перейдите в **Settings** → **API**
2. Скопируйте:
   - **Project URL**: `https://your-project-ref.supabase.co`
   - **anon public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6...`

### 3. Настройка в коде

Откройте файл `lib/config/supabase_config.dart` и замените:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://your-project-ref.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here';
  
  static const bool useLocalSupabase = false;
  
  static String get url => useLocalSupabase ? localSupabaseUrl : supabaseUrl;
  static String get anonKey => useLocalSupabase ? localSupabaseAnonKey : supabaseAnonKey;
}
```

### 4. Создание схемы базы данных

1. Перейдите в **SQL Editor** в Supabase
2. Скопируйте содержимое файла `supabase_schema.sql`
3. Выполните SQL запрос для создания всех таблиц

### 5. Настройка RLS (Row Level Security)

Схема уже включает политики безопасности:

- **Админы** видят все данные всех компаний
- **Пользователи** видят только данные своей компании
- **Контактные лица** видят только назначенное им оборудование

### 6. Тестовые данные

После создания схемы можете добавить тестовые данные:

```sql
-- Создание тестовой компании
INSERT INTO companies (id, name, description, contact_email) VALUES 
('550e8400-e29b-41d4-a716-446655440001', 'ООО "Тест Компания"', 'Тестовая компания для разработки', 'test@company.ru');

-- Создание тестовой площадки
INSERT INTO sites (company_id, name, address) VALUES 
('550e8400-e29b-41d4-a716-446655440001', 'Ещё одна тестовая площадка', 'г. Москва, ул. Тестовая, 1');

-- Создание тестового оборудования
INSERT INTO equipment (company_id, site_id, name, model, manufacturer, status) VALUES 
('550e8400-e29b-41d4-a716-446655440001', 
 (SELECT id FROM sites WHERE name = 'Ещё одна тестовая площадка' LIMIT 1),
 'Экскаватор №1', 'CAT 320D', 'Caterpillar', 'active');
```

## 🔧 Основные таблицы

### companies
- Компании-клиенты
- Основная информация о компании

### sites  
- Площадки компании
- Адреса и контактная информация

### user_profiles
- Профили пользователей (расширяет auth.users)
- Роли и права доступа

### equipment
- Оборудование компаний
- Привязка к площадкам и ответственным

### service_requests
- Сервисные заявки
- Статусы и одобрения

### parts_requests
- Заявки на запчасти
- Связь с сервисными заявками

### notifications
- Уведомления пользователей
- Поддержка realtime

## 🔐 Аутентификация

Система использует Supabase Auth:

1. **Email/Password** для веб-интерфейса
2. **Telegram ID** для привязки пользователей
3. **RLS политики** для безопасности данных

## 📊 Мониторинг

В Supabase Dashboard вы можете:

- Просматривать таблицы в **Table Editor**
- Анализировать запросы в **Logs**
- Настраивать webhooks в **Edge Functions**
- Мониторить производительность в **Reports**

## ⚡ Realtime

Приложение поддерживает realtime обновления:

- Новые уведомления
- Изменения статусов заявок
- Обновления оборудования

## 🚨 Безопасность

### RLS Политики включены для всех таблиц:

- Пользователи видят только данные своей компании
- Админы имеют полный доступ
- Контактные лица ограничены назначенным оборудованием

### Рекомендации:

1. Используйте сложные пароли для базы данных
2. Регулярно обновляйте ключи API
3. Мониторьте логи доступа
4. Настройте backup для важных данных

## 🛠️ Разработка

Для локальной разработки можете использовать Supabase CLI:

```bash
# Установка Supabase CLI
npm install -g supabase

# Инициализация локального проекта
supabase init

# Запуск локального Supabase
supabase start

# Применение миграций
supabase db push
```

Затем в `supabase_config.dart` установите `useLocalSupabase = true`.
