# 🚀 Деплой на Vercel

## Текущая ситуация
- ✅ У нас есть рабочая ссылка: `t-company-service.vercel.app`
- ✅ Vercel уже работает с Telegram Mini App
- ✅ У нас есть полный код приложения
- ✅ Настроена конфигурация Vercel

## Шаги для деплоя

### 1. Подключить репозиторий к Vercel

1. Перейди на [vercel.com](https://vercel.com)
2. Войди в свой аккаунт
3. Нажми **"New Project"**
4. Выбери репозиторий `nniikk99/t-company-service`
5. Настрой проект:
   - **Framework Preset**: Other
   - **Build Command**: `npm run vercel-build`
   - **Output Directory**: `.` (корень)
   - **Root Directory**: `.` (корень)

### 2. Настроить переменные окружения (если нужно)

В настройках проекта Vercel добавь:
- `SUPABASE_URL`: `https://kwunhuzfnjpcoeusnxzy.supabase.co`
- `SUPABASE_ANON_KEY`: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDM2MTksImV4cCI6MjA1OTYxOTYxOX0.2ppg8GtsGKE-ACMC__jSTy0gmn7eUya2xHagi9cdypE`

### 3. Деплой

1. Нажми **"Deploy"**
2. Дождись завершения сборки (5-10 минут)
3. Получишь новую ссылку или обновится существующая

### 4. Обновить BotFather

После успешного деплоя обнови URL в BotFather:
```
/setmenubutton
@Assistant_t_co_bot
T-Company Service
https://t-company-service.vercel.app/
```

## Преимущества Vercel

- ✅ **Быстрый деплой** - автоматически при каждом push
- ✅ **HTTPS** - включен по умолчанию
- ✅ **Telegram совместимость** - уже проверено
- ✅ **Простая настройка** - меньше проблем чем GitHub Pages
- ✅ **Хорошая производительность** - CDN по всему миру

## Если что-то пойдет не так

1. **Проверь логи сборки** в Vercel Dashboard
2. **Убедись, что скрипт `build_web.sh` исполняемый**
3. **Проверь, что все файлы загружены** в репозиторий

**Готов начать деплой на Vercel?** 🚀
