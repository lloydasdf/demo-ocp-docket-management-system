-- Keep the cases-page shell view's month code sourced directly from cases so
-- the client can build and apply the Docket Month filter.
CREATE OR REPLACE VIEW public.v_docket_shell
WITH (security_invoker = false)
AS
SELECT c.id,
       c.docket_type_id,
       c.docket_year,
       c.docket_number,
       c.docket_month_code,
       concat_ws('-', dt.prefix, c.docket_year::text, NULLIF(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0')) AS docket_display_number,
       dt.prefix AS docket_type_prefix,
       dt.name AS docket_type_name,
       c.created_at
FROM public.cases c
JOIN public.docket_types dt ON dt.id = c.docket_type_id
WHERE c.is_archived IS FALSE
  AND public.has_any_app_role(ARRAY['DEVELOPER','CHIEF','ADMIN','PROSECUTOR']);

COMMENT ON VIEW public.v_docket_shell IS
  'Cases page shell read model, including cases.docket_month_code for docket month filtering.';
