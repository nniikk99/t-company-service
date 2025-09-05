@echo off
echo Настройка Git репозитория...
git init
git add .
git commit -m "Создано T-Co Service приложение для Telegram Mini App"

echo Настройка удаленного репозитория...
git remote add origin https://github.com/nniikk.9/t_co_service.git

echo Создание ветки gh-pages...
git checkout -b gh-pages

echo Отправка в GitHub...
git push -u origin gh-pages

echo Готово! Приложение доступно по адресу:
echo https://nniikk.9.github.io/t_co_service/
pause
