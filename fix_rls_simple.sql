-- Упрощенный скрипт для исправления RLS политик
-- Выполняйте по частям, если возникают ошибки

-- Шаг 1: Включаем RLS
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;

-- Шаг 2: Удаляем старые политики (если есть)
DROP POLICY IF EXISTS "Users can view sites of their companies" ON sites;
DROP POLICY IF EXISTS "Users can view equipment of their companies" ON equipment;
DROP POLICY IF EXISTS "Users can manage sites of their companies" ON sites;
DROP POLICY IF EXISTS "Users can manage equipment of their companies" ON equipment;

-- Шаг 3: Создаем новые политики для sites
CREATE POLICY "Users can view sites of their companies"
ON sites FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = sites.company_inn
          AND uc.status = 'approved'
          AND uc.role <> 'pendingApproval'
    )
);

-- Шаг 4: Создаем политики для equipment
CREATE POLICY "Users can view equipment of their companies"
ON equipment FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = equipment.company_inn
          AND uc.status = 'approved'
          AND uc.role <> 'pendingApproval'
    )
);

-- Шаг 5: Политики для управления sites
CREATE POLICY "Users can manage sites of their companies"
ON sites FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = sites.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = sites.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
);

-- Шаг 6: Политики для управления equipment
CREATE POLICY "Users can manage equipment of their companies"
ON equipment FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = equipment.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_companies uc
        WHERE uc.user_id = auth.uid()
          AND uc.company_inn = equipment.company_inn
          AND uc.status = 'approved'
          AND uc.role IN ('companyResponsible', 'superAdmin', 'administrator', 'siteManager')
    )
);

-- Проверяем результат
SELECT 'RLS policies updated successfully' as status;
