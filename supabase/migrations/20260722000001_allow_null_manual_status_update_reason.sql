BEGIN;

ALTER TABLE public.case_manual_status_updates
  ALTER COLUMN reason DROP NOT NULL;

COMMIT;
