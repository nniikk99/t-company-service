# T-Company Service Web App

Telegram Mini App для сервисного обслуживания оборудования T-Company.

## Разработка

1. Установите Flutter SDK
2. Клонируйте репозиторий
3. Установите зависимости:
```bash
flutter pub get
```
4. Запустите в режиме разработки:
```bash
flutter run -d chrome
```

## Деплой

Приложение автоматически деплоится на GitHub Pages при пуше в ветку `main`.

URL приложения: `https://<username>.github.io/t_co_service/`

## Настройка в Telegram

1. Создайте бота через @BotFather
2. Включите Mini Apps в настройках бота
3. Добавьте URL вашего приложения в настройках бота
4. Используйте команду `/mybots` -> Ваш бот -> Bot Settings -> Menu Button для добавления кнопки меню
   
