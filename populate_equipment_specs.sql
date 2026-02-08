-- Пополнение технических характеристик оборудования
-- Эти данные взяты с сайта t-co.ru и будут храниться в колонке specifications (JSONB)

-- Обновление характеристик для Tennant T7
UPDATE equipment
SET specifications = '{
  "power": {"value": "1.5", "unit": "кВт", "label": "Мощность"},
  "voltage": {"value": "36", "unit": "В", "label": "Напряжение"},
  "weight": {"value": "220", "unit": "кг", "label": "Вес"},
  "productivity": {"value": "3800", "unit": "кв.м/ч", "label": "Производительность"},
  "cleaningWidth": {"value": "820", "unit": "мм", "label": "Ширина уборки"},
  "cleanWaterTank": {"value": "115", "unit": "л", "label": "Бак чистой воды"},
  "dirtyWaterTank": {"value": "123", "unit": "л", "label": "Бак грязной воды"}
}'::jsonb
WHERE model ILIKE '%T7%' AND manufacturer ILIKE '%Tennant%';

-- Обновление характеристик для Tennant T300
UPDATE equipment
SET specifications = '{
  "power": {"value": "0.75", "unit": "кВт", "label": "Мощность"},
  "weight": {"value": "115", "unit": "кг", "label": "Вес"},
  "productivity": {"value": "2100", "unit": "кв.м/ч", "label": "Производительность"},
  "cleaningWidth": {"value": "500", "unit": "мм", "label": "Ширина уборки"},
  "cleanWaterTank": {"value": "68", "unit": "л", "label": "Бак чистой воды"},
  "dirtyWaterTank": {"value": "72", "unit": "л", "label": "Бак грязной воды"}
}'::jsonb
WHERE model ILIKE '%T300%' AND manufacturer ILIKE '%Tennant%';

-- Обновление характеристик для IPC CT40
UPDATE equipment
SET specifications = '{
  "weight": {"value": "67", "unit": "кг", "label": "Вес"},
  "productivity": {"value": "1750", "unit": "кв.м/ч", "label": "Производительность"},
  "cleaningWidth": {"value": "500", "unit": "мм", "label": "Ширина уборки"},
  "cleanWaterTank": {"value": "40", "unit": "л", "label": "Бак чистой воды"},
  "dirtyWaterTank": {"value": "50", "unit": "л", "label": "Бак грязной воды"}
}'::jsonb
WHERE model ILIKE '%CT40%' AND manufacturer ILIKE '%IPC%';

-- Обновление характеристик для IPC CT70
UPDATE equipment
SET specifications = '{
  "weight": {"value": "90", "unit": "кг", "label": "Вес"},
  "productivity": {"value": "2475", "unit": "кв.м/ч", "label": "Производительность"},
  "cleaningWidth": {"value": "700", "unit": "мм", "label": "Ширина уборки"},
  "cleanWaterTank": {"value": "70", "unit": "л", "label": "Бак чистой воды"},
  "dirtyWaterTank": {"value": "75", "unit": "л", "label": "Бак грязной воды"}
}'::jsonb
WHERE model ILIKE '%CT70%' AND manufacturer ILIKE '%IPC%';
