-- ============================================================
-- МИГРАЦИЯ: Акт выполненных работ
-- Запустить в Supabase SQL Editor
-- ============================================================

-- 1. companies — юридические и банковские реквизиты
ALTER TABLE companies ADD COLUMN IF NOT EXISTS kpp VARCHAR(9);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS ogrn VARCHAR(15);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS org_form TEXT;             -- 'ИП' | 'ООО' | 'АО'
ALTER TABLE companies ADD COLUMN IF NOT EXISTS legal_address TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS director_name TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS director_basis TEXT;       -- 'Устав' | 'Доверенность №...'
ALTER TABLE companies ADD COLUMN IF NOT EXISTS registration_number TEXT;  -- № свидетельства ИП / ОГРН

-- Банковские (для будущего счёта на оплату)
ALTER TABLE companies ADD COLUMN IF NOT EXISTS bank_name TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS bik VARCHAR(9);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS checking_account VARCHAR(20);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS correspondent_account VARCHAR(20);

-- Документы / НДС
ALTER TABLE companies ADD COLUMN IF NOT EXISTS vat_included BOOLEAN DEFAULT FALSE;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS signature_url TEXT;        -- скан подписи
ALTER TABLE companies ADD COLUMN IF NOT EXISTS stamp_url TEXT;            -- скан печати

-- 2. service_requests — ссылки на сгенерированные документы
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS contract_number TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS act_url TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS act_number TEXT;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS act_generated_at TIMESTAMPTZ;
ALTER TABLE service_requests ADD COLUMN IF NOT EXISTS invoice_doc_url TEXT;

-- 3. request_documents — история документов по заявке (основа для будущего)
CREATE TABLE IF NOT EXISTS request_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL,    -- 'act' | 'invoice' | 'other'
  doc_number TEXT,
  file_url TEXT NOT NULL,
  generated_by UUID REFERENCES user_profiles(id),
  generated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS для request_documents
ALTER TABLE request_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view docs for their requests"
  ON request_documents FOR SELECT
  USING (
    request_id IN (
      SELECT id FROM service_requests
      WHERE user_id = auth.uid()
         OR assigned_engineer_id = auth.uid()
         OR company_id IN (
           SELECT company_id FROM user_companies WHERE user_id = auth.uid() AND status = 'approved'
         )
    )
  );
CREATE POLICY "Authenticated users can insert docs"
  ON request_documents FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- 4. Перезаписываем кэш API
NOTIFY pgrst, 'reload schema';
