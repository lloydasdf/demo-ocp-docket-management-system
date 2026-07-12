CREATE OR REPLACE FUNCTION public.get_cases_export_manifest(
  p_docket_year integer DEFAULT NULL,
  p_docket_type_id bigint DEFAULT NULL
)
RETURNS TABLE (
  docket_type_id bigint,
  docket_type_prefix text,
  docket_type_label text,
  docket_type_sort_order integer,
  docket_year integer,
  expected_case_count bigint
)
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    c.docket_type_id,
    NULLIF(dt.prefix, '') AS docket_type_prefix,
    NULLIF(dt.name, '') AS docket_type_label,
    dt.sort_order AS docket_type_sort_order,
    c.docket_year,
    count(*)::bigint AS expected_case_count
  FROM public.cases c
  JOIN public.docket_types dt ON dt.id = c.docket_type_id
  WHERE (p_docket_year IS NULL OR c.docket_year = p_docket_year)
    AND (p_docket_type_id IS NULL OR c.docket_type_id = p_docket_type_id)
    AND COALESCE(c.is_archived, false) IS FALSE
  GROUP BY
    c.docket_type_id,
    NULLIF(dt.prefix, ''),
    NULLIF(dt.name, ''),
    dt.sort_order,
    c.docket_year
  ORDER BY
    c.docket_year,
    dt.sort_order NULLS LAST,
    NULLIF(dt.prefix, ''),
    NULLIF(dt.name, '');
$$;

GRANT EXECUTE ON FUNCTION public.get_cases_export_manifest(integer, bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
