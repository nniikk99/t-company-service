import sys

path = r'c:\my_telegram_bot\t_co_service\lib\widgets\requests\request_details_screen.dart'

# Let's read it in binary to see exactly what's there
with open(path, 'rb') as f:
    data = f.read()

# We need to replace several garbled strings. 
# We'll try to find them by scanning for their likely UTF-8 or CP1251 patterns
try:
    content = data.decode('utf-8')
except UnicodeDecodeError:
    content = data.decode('cp1251') # Fallback if it's messed up

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

for old, new in replacements.items():
    content = content.replace(old, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS")
