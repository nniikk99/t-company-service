# 🔧 Исправление деплоя на Vercel

## Проблема
Vercel развернул старую версию приложения вместо нашей обновленной версии с правильным UI.

## Что нужно проверить в Vercel Dashboard

### 1. Настройки проекта
Перейди в настройки проекта `t-company-service` на Vercel:

1. **Build & Development Settings**:
   - **Framework Preset**: Other
   - **Build Command**: `npm run vercel-build`
   - **Output Directory**: `.` (корень)
   - **Root Directory**: `.` (корень)

### 2. Переменные окружения
Убедись, что есть переменные (если нужны):
- `SUPABASE_URL`: `https://kwunhuzfnjpcoeusnxzy.supabase.co`
- `SUPABASE_ANON_KEY`: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDM2MTksImV4cCI6MjA1OTYxOTYxOX0.2ppg8GtsGKE-ACMC__jSTy0gmn7eUya2xHagi9cdypE`

### 3. Принудительная пересборка
Если настройки правильные, но все еще старая версия:

1. **Перейди в раздел "Deployments"**
2. **Нажми "Redeploy"** на последнем деплое
3. **Или создай новый деплой** из ветки `main`

### 4. Проверь логи сборки
В разделе "Deployments" → "Build Logs" проверь:
- Запускается ли команда `npm run vercel-build`
- Выполняется ли скрипт `scripts/build_web.sh`
- Есть ли ошибки при сборке Flutter

## Альтернативное решение

Если Vercel не запускает наш скрипт сборки, можем:

1. **Собрать локально** и загрузить готовые файлы
2. **Использовать другой хостинг** (Netlify, GitHub Pages)
3. **Настроить Vercel вручную** через CLI

## Что должно получиться

После правильной сборки на Vercel должна быть наша версия с:
- ✅ Фиолетовым градиентом
- ✅ Правильным экраном авторизации
- ✅ Логотипом с велосипедом
- ✅ Полной функциональностью

**Проверь настройки Vercel и сообщи результат!** 🚀
