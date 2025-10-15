# 🚀 Инструкция по загрузке проекта на GitHub

## ⚠️ ВАЖНО! Безопасность прежде всего

Файл `lib/config/supabase_config.dart` содержит **РЕАЛЬНЫЕ** ключи Supabase и **УЖЕ ДОБАВЛЕН** в `.gitignore`.

### Перед загрузкой в Git убедитесь:

✅ Файл `lib/config/supabase_config.dart` в `.gitignore`  
✅ Создан файл-шаблон `lib/config/supabase_config.example.dart` (без реальных ключей)  
✅ Нет других файлов с секретными данными  

---

## 📝 Шаг 1: Создайте репозиторий на GitHub

1. Откройте [GitHub](https://github.com)
2. Нажмите **"New repository"**
3. Заполните:
   - **Repository name**: `t-co-service` (или другое имя)
   - **Description**: "Telegram Mini App для управления сервисными заявками"
   - **Visibility**: 
     - ✅ **Private** (рекомендуется, если есть бизнес-логика)
     - ⚠️ Public (только если уверены, что нет секретов)
   - ❌ Не создавайте README, .gitignore, LICENSE (они уже есть)
4. Нажмите **"Create repository"**

---

## 🔧 Шаг 2: Инициализируйте Git локально

Откройте терминал в папке проекта и выполните:

```bash
# Перейдите в папку проекта
cd c:\my_telegram_bot\t_co_service

# Инициализация Git
git init

# Добавьте все файлы (supabase_config.dart будет игнорирован)
git add .

# Проверьте что НЕ добавлено (должен быть supabase_config.dart)
git status

# ВАЖНО: Убедитесь что supabase_config.dart НЕ в списке!
# Если он там есть - НЕ ДЕЛАЙТЕ commit!
```

### 🛡️ Проверка безопасности

```bash
# Проверьте что файл с ключами игнорируется
git check-ignore lib/config/supabase_config.dart
# Должно вывести: lib/config/supabase_config.dart

# Если ничего не вывело - файл НЕ игнорируется! Не коммитьте!
```

---

## ✅ Шаг 3: Первый коммит

```bash
# Создайте первый коммит
git commit -m "Initial commit: T-Co Service with org_type feature

- Flutter приложение для управления сервисными заявками
- Интеграция с Supabase
- Система ролей и компаний
- Поддержка типов организаций (customer, supplier, service_partner)
- SQL миграции и документация"

# Переименуйте ветку в main (если нужно)
git branch -M main
```

---

## 🔗 Шаг 4: Подключите GitHub и загрузите

```bash
# Добавьте remote (замените YOUR_USERNAME и REPO_NAME)
git remote add origin https://github.com/YOUR_USERNAME/t-co-service.git

# Загрузите на GitHub
git push -u origin main
```

### Если требуется аутентификация:

**Вариант 1: Personal Access Token (рекомендуется)**
1. Откройте GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token → выберите `repo` scope
3. Скопируйте токен
4. При запросе пароля вставьте токен

**Вариант 2: GitHub Desktop**
1. Скачайте [GitHub Desktop](https://desktop.github.com/)
2. File → Add Local Repository → выберите папку проекта
3. Publish repository

---

## 📋 Шаг 5: Настройте README на GitHub

После загрузки:
1. Откройте репозиторий на GitHub
2. Отредактируйте `README.md`:
   - Замените `ВАШ_USERNAME` на свой username
   - Добавьте реальные контакты
   - Обновите описание (если нужно)

---

## 👥 Шаг 6: Инструкция для других разработчиков

Когда кто-то клонирует репозиторий:

```bash
# Клонировать репозиторий
git clone https://github.com/YOUR_USERNAME/t-co-service.git
cd t-co-service

# Установить зависимости
flutter pub get

# ВАЖНО: Создать файл конфигурации
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart

# Открыть и вставить свои ключи Supabase
# code lib/config/supabase_config.dart
```

Добавьте эту инструкцию в `README.md` в разделе "Установка".

---

## 🔄 Регулярная работа с Git

### Добавление изменений

```bash
# Посмотреть статус
git status

# Добавить конкретные файлы
git add lib/screens/new_screen.dart

# Или добавить все изменения
git add .

# Коммит
git commit -m "Add new feature"

# Загрузка на GitHub
git push
```

### Создание веток для новых фич

```bash
# Создать и переключиться на новую ветку
git checkout -b feature/new-feature

# Работайте, делайте коммиты
git add .
git commit -m "Work on new feature"

# Загрузите ветку
git push -u origin feature/new-feature

# Создайте Pull Request на GitHub
```

---

## 🚨 ЧТО ДЕЛАТЬ, ЕСЛИ СЛУЧАЙНО ЗАКОММИТИЛИ КЛЮЧИ

**Если ключи уже попали в Git, но НЕ в GitHub:**

```bash
# Отмените последний коммит (но сохраните изменения)
git reset --soft HEAD~1

# Проверьте что файл в .gitignore
git check-ignore lib/config/supabase_config.dart

# Удалите файл из индекса
git rm --cached lib/config/supabase_config.dart

# Коммитьте снова
git add .
git commit -m "Initial commit (без секретных ключей)"
```

**Если ключи УЖЕ на GitHub:**

1. 🔴 **СРОЧНО** смените все ключи в Supabase Dashboard!
2. Удалите репозиторий на GitHub
3. Очистите историю Git:
   ```bash
   rm -rf .git
   git init
   # Повторите шаги выше
   ```

---

## ✅ Чеклист перед загрузкой

- [ ] `.gitignore` создан и содержит `lib/config/supabase_config.dart`
- [ ] Выполнена команда `git check-ignore lib/config/supabase_config.dart`
- [ ] Файл `supabase_config.example.dart` создан (без ключей)
- [ ] `README.md` и `LICENSE` созданы
- [ ] Выполнен `git status` — файл с ключами НЕ в списке
- [ ] Репозиторий на GitHub создан (Private рекомендуется)
- [ ] Выполнены команды инициализации Git
- [ ] Проект успешно загружен на GitHub

---

## 📞 Помощь

Если что-то пошло не так:
- Проверьте [GitHub Docs](https://docs.github.com)
- Используйте [GitHub Desktop](https://desktop.github.com/) для визуального интерфейса
- Задайте вопрос в Issues репозитория

**Удачи! 🚀**

