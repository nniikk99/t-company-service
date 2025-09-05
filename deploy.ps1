# Скрипт для настройки и отправки в GitHub
Write-Host "Настройка удаленного репозитория..."
git remote add origin https://github.com/nniikk.9/t_co_service.git

Write-Host "Проверка статуса..."
git status

Write-Host "Отправка ветки gh-pages..."
git push -u origin gh-pages

Write-Host "Готово!"
