import sys
import os

path = r'c:\my_telegram_bot\t_co_service\lib\widgets\requests\request_details_screen.dart'

replacements = {
    'Р˜РЅРёС†РёР°С‚РѕСЂ': 'Инициатор',
    'РќР°Р·РЅР°С‡РёС‚СЊ РґР°С‚Сѓ РІС‹РµР·РґР°': 'Назначить дату выезда',
    'РџСЂРёСЃС‚СѓРїРёС‚СЊ Рє СЂР°Р±РѕС‚Рµ': 'Приступить к работе',
    'Р—Р°РІРµСЂС€РёС‚СЊ СЂР°Р±РѕС‚С‹ Рё СЃРґР°С‚СЊ РѕС‚С‡РµС‚': 'Завершить работы и сдать отчет',
    'РЎС„РѕСЂРјРёСЂРѕРІР°С‚СЊ / Р—Р°РіСЂСѓР·РёС‚СЊ СЃС‡РµС‚': 'Сформировать / Загрузить счет',
    'РџРѕРґС‚РІРµСЂРґРёС‚СЊ РѕРїР»Р°С‚Сѓ Рё Р·Р°РєСЂС‹С‚СЊ': 'Подтвердить оплату и закрыть',
    'Р”Р°С‚Р° РІС‹РµР·РґР° РЅР°Р·РЅР°С‡РµРЅР°!': 'Дата выезда назначена!',
    'РћС€РёР±РєР°:': 'Ошибка:',
}

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

for old, new in replacements.items():
    content = content.replace(old, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
