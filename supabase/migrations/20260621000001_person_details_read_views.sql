-- Person details read views for browser/client SELECT flows.
-- Development note: these views intentionally do not add RLS policies or
-- security filters while the read-refactor is being debugged.

CREATE OR REPLACE VIEW public.v_person_details AS
SELECT
  p.*,
  COALESCE(pa_alias.person_aliases, '[]'::jsonb) AS person_aliases,
  COALESCE(pa_addr.person_addresses, '[]'::jsonb) AS person_addresses
FROM public.persons p
LEFT JOIN LATERAL (
  SELECT jsonb_agg(
    jsonb_build_object(
      'alias_name', a.alias_name,
      'alias_type', a.alias_type,
      'is_active', a.is_active
    )
    ORDER BY a.is_active DESC NULLS LAST, a.alias_name
  ) AS person_aliases
  FROM public.person_aliases a
  WHERE a.person_id = p.id
) pa_alias ON true
LEFT JOIN LATERAL (
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', paddr.id,
      'is_primary', paddr.is_primary,
      'remarks', paddr.remarks,
      'addresses', CASE
        WHEN addr.id IS NULL THEN NULL::jsonb
        ELSE jsonb_build_object(
          'barangay', addr.barangay,
          'city', addr.city,
          'country', addr.country,
          'line1', addr.line1,
          'line2', addr.line2,
          'province', addr.province,
          'region', addr.region,
          'zip_code', addr.zip_code
        )
      END
    )
    ORDER BY paddr.is_primary DESC NULLS LAST, paddr.id
  ) AS person_addresses
  FROM public.person_addresses paddr
  LEFT JOIN public.addresses addr ON addr.id = paddr.address_id
  WHERE paddr.person_id = p.id
) pa_addr ON true;

COMMENT ON VIEW public.v_person_details IS 'Person details page read model with aliases and addresses. Intentionally policy-free for development debugging.';
