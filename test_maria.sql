DO $$ 
DECLARE
  maria_id uuid;
BEGIN
  SELECT id INTO maria_id FROM public.user_profiles WHERE last_name = 'Петрова' AND first_name = 'Мария' LIMIT 1;
  RAISE NOTICE 'Maria ID: %', maria_id;

  -- Let's check her company_id
  IF maria_id IS NOT NULL THEN
    -- Check if Maria has a company
    PERFORM company_id FROM public.user_profiles WHERE id = maria_id AND company_id IS NOT NULL;
    IF NOT FOUND THEN
      RAISE NOTICE 'Maria has no company_id!';
    ELSE
      RAISE NOTICE 'Maria has company_id';
    END IF;

    -- Update equipment models if needed. The equipment models or instances should have supplier_id.
    -- The issue states that Maria Petrova's equipment are missing. Let's see if Maria has equipment in 'equipment' table.
    -- Equipment table has company_id. Let's list equipment for Maria's company if she has one.
  END IF;
END $$;
