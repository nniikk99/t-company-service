-- Миграция: Добавление supplier_id в equipment и service_requests
-- Дата: 2025-01-XX
-- Описание: Добавляет связь между поставщиками, оборудованием и заявками

-- 1. Добавление supplier_id в таблицу equipment
ALTER TABLE equipment 
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN equipment.supplier_id IS 'ID поставщика, который поставил это оборудование';

-- 2. Добавление supplier_id в таблицу service_requests
ALTER TABLE service_requests 
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN service_requests.supplier_id IS 'ID поставщика, которому видна эта заявка (определяется из equipment при создании)';

-- 3. Индексы для производительности
CREATE INDEX IF NOT EXISTS idx_equipment_supplier_id ON equipment(supplier_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_supplier_id ON service_requests(supplier_id);

-- 4. Композитный индекс для частых запросов поставщика
CREATE INDEX IF NOT EXISTS idx_service_requests_supplier_status 
ON service_requests(supplier_id, status) 
WHERE supplier_id IS NOT NULL AND status != 'cancelled';

-- 5. Индекс для поиска заявок инженера
CREATE INDEX IF NOT EXISTS idx_service_requests_assigned_engineer 
ON service_requests(assigned_engineer_id) 
WHERE assigned_engineer_id IS NOT NULL;

