# T-Co Service 🔧

**Telegram Mini App** для управления сервисными заявками, оборудованием и компаниями.

## 📋 Описание проекта

T-Co Service — это комплексная система управления сервисным обслуживанием, разработанная на Flutter с использованием Supabase в качестве backend. Приложение позволяет:

- 🏢 Управлять компаниями разных типов (заказчики, поставщики, сервисные партнеры)
- 🔧 Создавать и отслеживать сервисные заявки
- 📦 Управлять оборудованием и запчастями
- 👥 Управлять пользователями и ролями
- 📊 Анализировать статистику и производительность
- 🔔 Получать уведомления о важных событиях

## 🚀 Технологический стек

- **Frontend**: Flutter / Dart
- **Backend**: Supabase (PostgreSQL)
- **Аутентификация**: Supabase Auth
- **Хранилище**: Supabase Storage
- **Real-time**: Supabase Realtime
- **Интеграция**: Telegram Bot API

## 📦 Основные функции

### Управление компаниями
- Три типа организаций:
  - 🏢 **Заказчик** — получает услуги
  - 📦 **Поставщик** — продаёт товары
  - 🔧 **Сервисный партнер** — оказывает услуги
- Система заявок на создание компаний
- Привязка пользователей к нескольким компаниям

### Роли пользователей
- **Супер-администратор** — полный доступ ко всей системе
- **Администратор** — управление пользователями и компаниями
- **Ответственное лицо компании** — управление своей компанией
- **Менеджер площадки** — управление конкретными площадками
- **Оператор ПМ** — работа с оборудованием
- **Инженер** — выполнение сервисных заявок
- **Поставщик** — управление товарами

### Управление оборудованием
- Регистрация оборудования с характеристиками
- Привязка к площадкам и ответственным лицам
- Отслеживание статуса и истории обслуживания
- Загрузка фотографий и документации

### Сервисные заявки
- Создание заявок на обслуживание/ремонт
- Управление приоритетами и статусами
- Назначение исполнителей
- Отслеживание стоимости и сроков

## 🛠️ Установка и настройка

### Предварительные требования

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Аккаунт Supabase
- Git

### Шаг 1: Клонирование репозитория

```bash
git clone https://github.com/ВАШ_USERNAME/t-co-service.git
cd t-co-service
```

### Шаг 2: Установка зависимостей

```bash
flutter pub get
```

### Шаг 3: Настройка Supabase

1. Создайте проект в [Supabase](https://supabase.com)
2. Скопируйте URL и anon key из настроек проекта
3. Создайте файл `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'ВАШ_SUPABASE_URL';
  static const String supabaseAnonKey = 'ВАШ_ANON_KEY';
}
```

### Шаг 4: Применение миграций

Откройте **Supabase SQL Editor** и выполните миграции в следующем порядке:

1. `supabase_schema.sql` — основная схема БД
2. `user_companies_schema.sql` — система связей пользователь-компания
3. `apply_migrations.sql` — все дополнительные миграции (включая org_type)

Или выполните один объединённый файл:
```bash
supabase db reset
# Затем выполните apply_migrations.sql в SQL Editor
```

Подробная инструкция в файле [SUPABASE_SETUP.md](./SUPABASE_SETUP.md)

### Шаг 5: Запуск приложения

```bash
# Для Web
flutter run -d chrome

# Для Android
flutter run -d android

# Для iOS
flutter run -d ios
```

## 📚 Документация

- [QUICK_SETUP.md](./QUICK_SETUP.md) — быстрый старт
- [SUPABASE_SETUP.md](./SUPABASE_SETUP.md) — настройка Supabase
- [MIGRATION_org_type_GUIDE.md](./MIGRATION_org_type_GUIDE.md) — миграция типов организаций
- [docs/equipment_specifications_guide.md](./docs/equipment_specifications_guide.md) — спецификации оборудования
- [docs/supplier_marketplace_roadmap.md](./docs/supplier_marketplace_roadmap.md) — roadmap маркетплейса
- [docs/test_engineer_role_management.md](./docs/test_engineer_role_management.md) — управление ролью инженера

## 🗄️ Структура проекта

```
t-co-service/
├── lib/
│   ├── config/           # Конфигурация приложения
│   ├── models/           # Модели данных
│   ├── screens/          # Экраны приложения
│   ├── services/         # Бизнес-логика и API
│   ├── widgets/          # Переиспользуемые виджеты
│   ├── theme/            # Темы оформления
│   └── utils/            # Утилиты
├── assets/               # Изображения и ресурсы
├── docs/                 # Документация
├── *.sql                 # SQL миграции и скрипты
└── web/                  # Web ресурсы
```

## 🔐 Безопасность

**Важно!** Никогда не коммитьте в Git:
- ❌ Supabase URL и ключи
- ❌ API токены
- ❌ Пароли и credentials
- ❌ Личные данные пользователей

Используйте `.env` файлы или переменные окружения для хранения чувствительных данных.

## 🚢 Деплой

### Web
```bash
flutter build web
# Загрузите содержимое build/web на хостинг
```

### Android
```bash
flutter build apk --release
# APK файл будет в build/app/outputs/flutter-apk/
```

### iOS
```bash
flutter build ios --release
# Загрузите в App Store Connect
```

## 🧪 Тестирование

```bash
# Запуск тестов
flutter test

# Анализ кода
flutter analyze

# Форматирование кода
flutter format .
```

## 📝 Последние обновления

### v1.1.0 (2025-10-15)
- ✨ Добавлена поддержка типов организаций (customer, supplier, service_partner)
- 🎨 Улучшен UI экрана управления клиентами
- 📦 Добавлена модель Company
- 🔧 Обновлены миграции и триггеры БД

### v1.0.0 (2025-09-10)
- 🎉 Первый релиз
- ✅ Базовая функциональность
- 🔐 Система аутентификации
- 📱 Telegram Mini App интеграция

## 🤝 Вклад в проект

Мы приветствуем любой вклад! Чтобы внести изменения:

1. Форкните репозиторий
2. Создайте ветку для новой функции (`git checkout -b feature/amazing-feature`)
3. Сделайте коммит (`git commit -m 'Add amazing feature'`)
4. Запушьте в ветку (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. Подробности в файле [LICENSE](./LICENSE).

## 👨‍💻 Авторы

- **Ваше имя** - *Initial work*

## 📞 Контакты

- Email: your.email@example.com
- Telegram: @yourusername
- GitHub: [@yourusername](https://github.com/yourusername)

## 🙏 Благодарности

- Flutter команде за отличный фреймворк
- Supabase за мощный backend-as-a-service
- Всем контрибьюторам проекта

---

⭐️ Если проект оказался полезным, поставьте звезду на GitHub!

