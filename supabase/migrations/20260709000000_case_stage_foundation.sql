BEGIN;

-- Case Stage foundation for phased Case Status / Case Stage split.
-- This migration intentionally keeps legacy current_status_id/status_id fields and
-- does not refactor event RPCs yet.

CREATE TABLE IF NOT EXISTS public.case_stages (
  id bigserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  display_label varchar(100) NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_final_stage boolean NOT NULL DEFAULT false,
  is_milestone boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.case_stage_colors (
  id bigserial PRIMARY KEY,
  stage_id bigint NOT NULL REFERENCES public.case_stages(id) ON DELETE CASCADE,
  color_name text,
  background_class text,
  text_class text,
  border_class text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT case_stage_colors_stage_id_key UNIQUE (stage_id)
);

ALTER TABLE public.case_private_details
  ADD COLUMN IF NOT EXISTS current_case_status_id bigint REFERENCES public.case_statuses(id),
  ADD COLUMN IF NOT EXISTS current_case_status_date date,
  ADD COLUMN IF NOT EXISTS current_case_status_remarks text,
  ADD COLUMN IF NOT EXISTS current_case_stage_id bigint REFERENCES public.case_stages(id),
  ADD COLUMN IF NOT EXISTS current_case_stage_date date,
  ADD COLUMN IF NOT EXISTS current_case_stage_remarks text;

ALTER TABLE public.case_events
  ADD COLUMN IF NOT EXISTS case_status_id bigint REFERENCES public.case_statuses(id),
  ADD COLUMN IF NOT EXISTS case_stage_id bigint REFERENCES public.case_stages(id);

CREATE TABLE IF NOT EXISTS public.case_stage_history (
  id bigserial PRIMARY KEY,
  case_id bigint NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  from_stage_id bigint REFERENCES public.case_stages(id),
  to_stage_id bigint REFERENCES public.case_stages(id),
  changed_by_user_id bigint REFERENCES public.users(id),
  changed_at timestamp with time zone NOT NULL DEFAULT now(),
  stage_date date,
  remarks text,
  case_event_id bigint REFERENCES public.case_events(id) ON DELETE SET NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.case_stages IS 'Reference table for automatic workflow stages split out from broad case statuses.';
COMMENT ON TABLE public.case_stage_history IS 'Workflow stage transition history backfilled from legacy case_status_history during phased Case Status / Case Stage split.';
COMMENT ON COLUMN public.case_private_details.current_case_status_id IS 'Broad legal outcome status. During phased refactor, legacy current_status_id remains for compatibility.';
COMMENT ON COLUMN public.case_private_details.current_case_stage_id IS 'Automatic workflow stage. During phased refactor, legacy current_status_id remains for compatibility.';
COMMENT ON COLUMN public.case_events.case_status_id IS 'Broad legal outcome status associated with this timeline event. Legacy status_id remains for compatibility.';
COMMENT ON COLUMN public.case_events.case_stage_id IS 'Automatic workflow stage associated with this timeline event. Legacy status_id remains for compatibility.';

-- Keep existing workflow status rows in case_statuses active for now because current RPCs
-- and frontend flows still read/write legacy status_id/current_status_id during the phased refactor.
INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active)
VALUES
  ('PENDING', 'Pending', 20, false, false, true),
  ('FILED', 'Filed', 96, true, true, true),
  ('DISMISSED', 'Dismissed', 100, true, true, true),
  ('MIXED_RESULT', 'Mixed Result', 110, true, true, true)
ON CONFLICT (code) DO UPDATE SET
  display_label = EXCLUDED.display_label,
  sort_order = EXCLUDED.sort_order,
  is_final = EXCLUDED.is_final,
  is_milestone = EXCLUDED.is_milestone,
  is_active = true;

INSERT INTO public.case_stages (code, display_label, sort_order, is_final_stage, is_milestone, is_active)
VALUES
  ('PENDING', 'Pending', 20, false, false, true),
  ('RESO_FOR_APPROVAL', 'Reso for Approval', 80, false, true, true),
  ('FOR_FILING', 'For Filing', 90, false, true, true),
  ('FILED_OTHER_RESO_FOR_APPROVAL', 'Filed; other resolution for approval', 92, false, true, true),
  ('FILED_OTHER_INFO_FOR_FILING', 'Filed; other info for filing', 94, false, true, true),
  ('FILED', 'Filed', 96, true, true, true),
  ('DISMISSED', 'Dismissed', 100, true, true, true),
  ('MIXED_RESULT', 'Mixed Result', 110, true, true, true)
ON CONFLICT (code) DO UPDATE SET
  display_label = EXCLUDED.display_label,
  sort_order = EXCLUDED.sort_order,
  is_final_stage = EXCLUDED.is_final_stage,
  is_milestone = EXCLUDED.is_milestone,
  is_active = true,
  updated_at = now();

WITH stage_color_seed(code, color_name, background_class, text_class, border_class) AS (
  VALUES
    ('PENDING', 'amber', 'bg-amber-50', 'text-amber-800', 'border-amber-200'),
    ('RESO_FOR_APPROVAL', 'blue', 'bg-blue-50', 'text-blue-800', 'border-blue-200'),
    ('FOR_FILING', 'violet', 'bg-violet-50', 'text-violet-800', 'border-violet-200'),
    ('FILED_OTHER_RESO_FOR_APPROVAL', 'indigo', 'bg-indigo-50', 'text-indigo-800', 'border-indigo-200'),
    ('FILED_OTHER_INFO_FOR_FILING', 'cyan', 'bg-cyan-50', 'text-cyan-800', 'border-cyan-200'),
    ('FILED', 'green', 'bg-green-50', 'text-green-800', 'border-green-200'),
    ('DISMISSED', 'slate', 'bg-slate-50', 'text-slate-800', 'border-slate-200'),
    ('MIXED_RESULT', 'orange', 'bg-orange-50', 'text-orange-800', 'border-orange-200')
)
INSERT INTO public.case_stage_colors (stage_id, color_name, background_class, text_class, border_class, is_active)
SELECT cs.id, seed.color_name, seed.background_class, seed.text_class, seed.border_class, true
FROM stage_color_seed seed
JOIN public.case_stages cs ON cs.code = seed.code
ON CONFLICT (stage_id) DO UPDATE SET
  color_name = EXCLUDED.color_name,
  background_class = EXCLUDED.background_class,
  text_class = EXCLUDED.text_class,
  border_class = EXCLUDED.border_class,
  is_active = true,
  updated_at = now();

WITH status_stage_map(old_code, broad_status_code, stage_code) AS (
  VALUES
    ('PENDING', 'PENDING', 'PENDING'),
    ('RESO_FOR_APPROVAL', 'PENDING', 'RESO_FOR_APPROVAL'),
    ('FOR_FILING', 'PENDING', 'FOR_FILING'),
    ('FILED_OTHER_RESO_FOR_APPROVAL', 'PENDING', 'FILED_OTHER_RESO_FOR_APPROVAL'),
    ('FILED_OTHER_INFO_FOR_FILING', 'PENDING', 'FILED_OTHER_INFO_FOR_FILING'),
    ('FILED', 'FILED', 'FILED'),
    ('DISMISSED', 'DISMISSED', 'DISMISSED'),
    ('MIXED_RESULT', 'MIXED_RESULT', 'MIXED_RESULT')
), mapped_details AS (
  SELECT
    cpd.case_id,
    COALESCE(map.broad_status_code, 'PENDING') AS broad_status_code,
    COALESCE(map.stage_code, 'PENDING') AS stage_code,
    cpd.current_status_date,
    cpd.current_status_remarks
  FROM public.case_private_details cpd
  LEFT JOIN public.case_statuses old_status ON old_status.id = cpd.current_status_id
  LEFT JOIN status_stage_map map ON map.old_code = old_status.code
)
UPDATE public.case_private_details cpd
SET
  current_case_status_id = broad_status.id,
  current_case_status_date = COALESCE(cpd.current_case_status_date, mapped.current_status_date),
  current_case_status_remarks = COALESCE(cpd.current_case_status_remarks, mapped.current_status_remarks),
  current_case_stage_id = stage.id,
  current_case_stage_date = COALESCE(cpd.current_case_stage_date, mapped.current_status_date),
  current_case_stage_remarks = COALESCE(cpd.current_case_stage_remarks, mapped.current_status_remarks)
FROM mapped_details mapped
JOIN public.case_statuses broad_status ON broad_status.code = mapped.broad_status_code
JOIN public.case_stages stage ON stage.code = mapped.stage_code
WHERE cpd.case_id = mapped.case_id
  AND (
    cpd.current_case_status_id IS DISTINCT FROM broad_status.id OR
    cpd.current_case_stage_id IS DISTINCT FROM stage.id OR
    (cpd.current_case_status_date IS NULL AND mapped.current_status_date IS NOT NULL) OR
    (cpd.current_case_stage_date IS NULL AND mapped.current_status_date IS NOT NULL) OR
    (cpd.current_case_status_remarks IS NULL AND mapped.current_status_remarks IS NOT NULL) OR
    (cpd.current_case_stage_remarks IS NULL AND mapped.current_status_remarks IS NOT NULL)
  );

WITH status_stage_map(old_code, broad_status_code, stage_code) AS (
  VALUES
    ('PENDING', 'PENDING', 'PENDING'),
    ('RESO_FOR_APPROVAL', 'PENDING', 'RESO_FOR_APPROVAL'),
    ('FOR_FILING', 'PENDING', 'FOR_FILING'),
    ('FILED_OTHER_RESO_FOR_APPROVAL', 'PENDING', 'FILED_OTHER_RESO_FOR_APPROVAL'),
    ('FILED_OTHER_INFO_FOR_FILING', 'PENDING', 'FILED_OTHER_INFO_FOR_FILING'),
    ('FILED', 'FILED', 'FILED'),
    ('DISMISSED', 'DISMISSED', 'DISMISSED'),
    ('MIXED_RESULT', 'MIXED_RESULT', 'MIXED_RESULT')
), mapped_events AS (
  SELECT
    ce.id,
    map.broad_status_code,
    map.stage_code
  FROM public.case_events ce
  JOIN public.case_statuses old_status ON old_status.id = ce.status_id
  JOIN status_stage_map map ON map.old_code = old_status.code
)
UPDATE public.case_events ce
SET
  case_status_id = broad_status.id,
  case_stage_id = stage.id
FROM mapped_events mapped
JOIN public.case_statuses broad_status ON broad_status.code = mapped.broad_status_code
JOIN public.case_stages stage ON stage.code = mapped.stage_code
WHERE ce.id = mapped.id
  AND (ce.case_status_id IS DISTINCT FROM broad_status.id OR ce.case_stage_id IS DISTINCT FROM stage.id);

WITH status_stage_map(old_code, stage_code) AS (
  VALUES
    ('PENDING', 'PENDING'),
    ('RESO_FOR_APPROVAL', 'RESO_FOR_APPROVAL'),
    ('FOR_FILING', 'FOR_FILING'),
    ('FILED_OTHER_RESO_FOR_APPROVAL', 'FILED_OTHER_RESO_FOR_APPROVAL'),
    ('FILED_OTHER_INFO_FOR_FILING', 'FILED_OTHER_INFO_FOR_FILING'),
    ('FILED', 'FILED'),
    ('DISMISSED', 'DISMISSED'),
    ('MIXED_RESULT', 'MIXED_RESULT')
), mapped_history AS (
  SELECT
    csh.id AS status_history_id,
    csh.case_id,
    from_stage.id AS from_stage_id,
    to_stage.id AS to_stage_id,
    csh.changed_by_user_id,
    csh.changed_at,
    csh.status_date AS stage_date,
    csh.remarks,
    csh.case_event_id
  FROM public.case_status_history csh
  LEFT JOIN public.case_statuses from_status ON from_status.id = csh.from_status_id
  LEFT JOIN status_stage_map from_map ON from_map.old_code = from_status.code
  LEFT JOIN public.case_stages from_stage ON from_stage.code = from_map.stage_code
  JOIN public.case_statuses to_status ON to_status.id = csh.to_status_id
  LEFT JOIN status_stage_map to_map ON to_map.old_code = to_status.code
  JOIN public.case_stages to_stage ON to_stage.code = COALESCE(to_map.stage_code, 'PENDING')
)
INSERT INTO public.case_stage_history (
  case_id,
  from_stage_id,
  to_stage_id,
  changed_by_user_id,
  changed_at,
  stage_date,
  remarks,
  case_event_id
)
SELECT
  mapped.case_id,
  mapped.from_stage_id,
  mapped.to_stage_id,
  mapped.changed_by_user_id,
  mapped.changed_at,
  mapped.stage_date,
  mapped.remarks,
  mapped.case_event_id
FROM mapped_history mapped
WHERE NOT EXISTS (
  SELECT 1
  FROM public.case_stage_history existing
  WHERE existing.case_id = mapped.case_id
    AND existing.from_stage_id IS NOT DISTINCT FROM mapped.from_stage_id
    AND existing.to_stage_id IS NOT DISTINCT FROM mapped.to_stage_id
    AND existing.changed_by_user_id IS NOT DISTINCT FROM mapped.changed_by_user_id
    AND existing.changed_at IS NOT DISTINCT FROM mapped.changed_at
    AND existing.stage_date IS NOT DISTINCT FROM mapped.stage_date
    AND existing.remarks IS NOT DISTINCT FROM mapped.remarks
    AND existing.case_event_id IS NOT DISTINCT FROM mapped.case_event_id
);

CREATE INDEX IF NOT EXISTS idx_case_private_details_current_case_status_id ON public.case_private_details(current_case_status_id);
CREATE INDEX IF NOT EXISTS idx_case_private_details_current_case_stage_id ON public.case_private_details(current_case_stage_id);
CREATE INDEX IF NOT EXISTS idx_case_private_details_current_case_stage_date ON public.case_private_details(current_case_stage_date);
CREATE INDEX IF NOT EXISTS idx_case_events_case_status_id ON public.case_events(case_status_id);
CREATE INDEX IF NOT EXISTS idx_case_events_case_stage_id ON public.case_events(case_stage_id);
CREATE INDEX IF NOT EXISTS idx_case_stage_history_case_time ON public.case_stage_history(case_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_case_stage_history_stage ON public.case_stage_history(to_stage_id);
CREATE INDEX IF NOT EXISTS idx_case_stage_history_case_event_id ON public.case_stage_history(case_event_id);

CREATE OR REPLACE VIEW public.v_ref_case_stages AS
SELECT
  id,
  code,
  display_label,
  sort_order,
  is_final_stage,
  is_milestone,
  is_active,
  created_at,
  updated_at
FROM public.case_stages
WHERE is_active = true;

COMMENT ON VIEW public.v_ref_case_stages IS 'Frontend reference view for active case workflow stages.';

CREATE OR REPLACE VIEW public.v_case_stage_history_detail AS
SELECT
  csh.id,
  csh.case_id,
  csh.from_stage_id,
  fs.code AS from_stage_code,
  fs.display_label AS from_stage_label,
  csh.to_stage_id,
  ts.code AS to_stage_code,
  ts.display_label AS to_stage_label,
  csh.changed_by_user_id,
  csh.changed_at,
  csh.stage_date,
  csh.remarks,
  csh.case_event_id
FROM public.case_stage_history csh
LEFT JOIN public.case_stages fs ON fs.id = csh.from_stage_id
LEFT JOIN public.case_stages ts ON ts.id = csh.to_stage_id;

COMMENT ON VIEW public.v_case_stage_history_detail IS 'Frontend case-stage-history read view for phased Case Status / Case Stage split.';

CREATE OR REPLACE VIEW public.v_docket_quickdetails AS
WITH latest_assignment AS (
  SELECT DISTINCT ON (ca.case_id)
    ca.case_id,
    ca.prosecutor_id,
    ca.assigned_at,
    ca.id
  FROM public.case_assignments ca
  WHERE ca.unassigned_at IS NULL
    AND ca.is_voided IS FALSE
  ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
)
SELECT
  c.id,
  c.date_received,
  cs.code AS current_status_code,
  cs.display_label AS current_status_label,
  p.full_name AS prosecutor_full_name,
  p.short_name AS prosecutor_short_name,
  cpd.current_status_id,
  cpd.current_status_date,
  cpd.current_case_status_id,
  cpd.current_case_status_date,
  cpd.current_case_status_remarks,
  broad_status.code AS current_case_status_code,
  broad_status.display_label AS current_case_status_label,
  cpd.current_case_stage_id,
  cpd.current_case_stage_date,
  cpd.current_case_stage_remarks,
  stage.code AS current_case_stage_code,
  stage.display_label AS current_case_stage_label
FROM public.cases c
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_statuses cs ON cs.id = cpd.current_status_id
LEFT JOIN public.case_statuses broad_status ON broad_status.id = cpd.current_case_status_id
LEFT JOIN public.case_stages stage ON stage.id = cpd.current_case_stage_id
LEFT JOIN latest_assignment la ON la.case_id = c.id
LEFT JOIN public.prosecutors p ON p.id = la.prosecutor_id
WHERE NOT c.is_archived;

COMMENT ON VIEW public.v_docket_quickdetails IS 'Cases page quick details read model for prosecutor, legacy status, split case status, split case stage, and received date. Intentionally policy-free for development debugging.';

CREATE OR REPLACE VIEW public.v_case_details_page AS
 WITH latest_assignment AS (
         SELECT DISTINCT ON (ca.case_id) ca.case_id,
            ca.prosecutor_id,
            ca.staff_id,
            ca.assigned_at,
            ca.id
           FROM public.case_assignments ca
          WHERE ca.unassigned_at IS NULL AND COALESCE(ca.is_voided, false) IS FALSE
          ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
        ), violation_summary AS (
         SELECT cv.case_id,
            string_agg(COALESCE(NULLIF(btrim(cv.raw_violation_text), ''::text), v.title), ', '::text ORDER BY cv.violation_order, cv.id) AS violations
           FROM (public.case_violations cv
             LEFT JOIN public.violations v ON ((v.id = cv.violation_id)))
          WHERE COALESCE(cv.is_deleted, false) IS FALSE
          GROUP BY cv.case_id
        ), note_summary AS (
         SELECT n.case_id,
            jsonb_agg(jsonb_build_object('id', n.id, 'note_text', n.note_text, 'is_private', n.is_private, 'created_by_user_id', n.created_by_user_id, 'created_at', n.created_at, 'updated_at', n.updated_at) ORDER BY n.created_at DESC, n.id DESC) AS notes
           FROM public.notes n
          WHERE COALESCE(n.is_deleted, false) IS FALSE
          GROUP BY n.case_id
        ), case_address_summary AS (
         SELECT ca.case_id,
            jsonb_agg(jsonb_build_object('id', ca.id, 'address_id', ca.address_id, 'address_type_id', ca.address_type_id, 'address_type_label', at.display_label, 'is_primary', ca.is_primary, 'remarks', ca.remarks, 'addresses', jsonb_build_object('barangay', a.barangay, 'city', a.city, 'country', a.country, 'line1', a.line1, 'line2', a.line2, 'province', a.province, 'region', a.region, 'zip_code', a.zip_code)) ORDER BY ca.is_primary DESC, ca.id) AS case_addresses
           FROM ((public.case_addresses ca
             JOIN public.addresses a ON ((a.id = ca.address_id)))
             LEFT JOIN public.address_types at ON ((at.id = ca.address_type_id)))
          WHERE COALESCE(ca.is_deleted, false) IS FALSE
          GROUP BY ca.case_id
        )
 SELECT c.id,
    c.docket_type_id,
    c.docket_year,
    c.docket_number,
    c.docket_month_code,
    c.date_received,
    c.created_by_user_id,
    c.updated_by_user_id,
    c.is_archived,
    c.created_at,
    c.updated_at,
    c.region_code,
    c.case_classification_id,
    concat_ws('-'::text, c.region_code, dt.prefix, (right((c.docket_year)::text, 2) || COALESCE(c.docket_month_code, ''::text)), lpad((c.docket_number)::text, 6, '0'::text)) AS docket_display_number,
    dt.prefix AS docket_type_prefix,
    dt.name AS docket_type_name,
    vs.violations,
    cpd.source,
    cpd.remarks,
    cpd.legacy_source_file,
    cpd.legacy_source_sheet,
    cpd.legacy_row_number,
    cpd.legacy_raw_json,
    cpd.is_summary_procedure,
    cpd.summary_text,
    cpd.current_status_id,
    cpd.current_status_date,
    cpd.current_status_approved_date_raw,
    cpd.current_status_approved_date_raw AS status_approved_date_raw,
    NULL::date AS status_approved_date,
    cpd.current_status_raw,
    cpd.current_status_remarks,
    cs.code AS current_status_code,
    cs.display_label AS current_status_label,
    la.prosecutor_id AS current_prosecutor_id,
    p.short_name AS prosecutor_short_name,
    p.full_name AS prosecutor_full_name,
    la.staff_id AS current_staff_id,
    st.short_name AS staff_short_name,
    st.full_name AS staff_full_name,
    la.assigned_at AS current_assigned_at,
    NULL::text AS case_classification_code,
    NULL::text AS case_classification_name,
    cc.display_label AS case_classification_label,
    cc.description AS case_classification_description,
    NULL::text AS gdrive_folder_id,
    NULL::text AS gdrive_folder_link,
    NULL::text AS gdrive_folder_name,
    NULL::text AS gdrive_folder_status,
    NULL::timestamp with time zone AS gdrive_folder_last_scanned_at,
    NULL::text AS court_codes,
    NULL::text AS criminal_case_numbers,
    NULL::boolean AS court_needs_review,
    COALESCE(cas.case_addresses, '[]'::jsonb) AS case_addresses,
    COALESCE(ns.notes, '[]'::jsonb) AS notes,
    cpd.current_case_status_id,
    cpd.current_case_status_date,
    cpd.current_case_status_remarks,
    broad_status.code AS current_case_status_code,
    broad_status.display_label AS current_case_status_label,
    cpd.current_case_stage_id,
    cpd.current_case_stage_date,
    cpd.current_case_stage_remarks,
    stage.code AS current_case_stage_code,
    stage.display_label AS current_case_stage_label
   FROM ((((((((((((public.cases c
     JOIN public.docket_types dt ON ((dt.id = c.docket_type_id)))
     LEFT JOIN public.case_private_details cpd ON ((cpd.case_id = c.id)))
     LEFT JOIN public.case_statuses cs ON ((cs.id = cpd.current_status_id)))
     LEFT JOIN public.case_statuses broad_status ON ((broad_status.id = cpd.current_case_status_id)))
     LEFT JOIN public.case_stages stage ON ((stage.id = cpd.current_case_stage_id)))
     LEFT JOIN latest_assignment la ON ((la.case_id = c.id)))
     LEFT JOIN public.prosecutors p ON ((p.id = la.prosecutor_id)))
     LEFT JOIN public.staff st ON ((st.id = la.staff_id)))
     LEFT JOIN public.case_classifications cc ON ((cc.id = c.case_classification_id)))
     LEFT JOIN violation_summary vs ON ((vs.case_id = c.id)))
     LEFT JOIN note_summary ns ON ((ns.case_id = c.id)))
     LEFT JOIN case_address_summary cas ON ((cas.case_id = c.id)))
  WHERE (NOT c.is_archived);

COMMENT ON VIEW public.v_case_details_page IS 'Case details page read model with legacy status plus split case status and case stage fields. Intentionally policy-free for development debugging.';

CREATE OR REPLACE VIEW public.v_case_timeline AS
SELECT
  ce.id AS case_event_id,
  ce.case_id,
  dt.prefix AS docket_type,
  c.docket_year,
  c.docket_month_code,
  c.docket_number,
  concat_ws('-', c.region_code, dt.prefix, right(c.docket_year::text, 2) || COALESCE(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0')) AS docket_display_number,
  cet.code AS event_type_code,
  cet.display_label AS event_type_label,
  cet.category AS event_category,
  ce.event_date,
  ce.event_time,
  ce.event_order,
  ce.title,
  ce.description,
  ce.status_id,
  cs.code AS status_code,
  cs.display_label AS status_label,
  ce.prosecutor_id,
  p.short_name AS prosecutor_short_name,
  ce.staff_id,
  st.short_name AS staff_short_name,
  ce.court_id,
  co.name AS court_name,
  ce.details_jsonb,
  ce.source,
  ce.source_table,
  ce.source_id,
  ce.legacy_source_file,
  ce.legacy_source_sheet,
  ce.legacy_row_number,
  ce.legacy_line_order,
  ce.needs_review,
  ce.review_reason,
  ce.is_voided,
  ce.created_at,
  ce.updated_at,
  ce.void_reason,
  ce.voided_at,
  ce.voided_by_user_id,
  vu.email AS voided_by_email,
  ce.case_status_id,
  event_status.code AS case_status_code,
  event_status.display_label AS case_status_label,
  ce.case_stage_id,
  event_stage.code AS case_stage_code,
  event_stage.display_label AS case_stage_label
FROM public.case_events ce
JOIN public.cases c ON c.id = ce.case_id
JOIN public.docket_types dt ON dt.id = c.docket_type_id
JOIN public.case_event_types cet ON cet.id = ce.event_type_id
LEFT JOIN public.case_statuses cs ON cs.id = ce.status_id
LEFT JOIN public.case_statuses event_status ON event_status.id = ce.case_status_id
LEFT JOIN public.case_stages event_stage ON event_stage.id = ce.case_stage_id
LEFT JOIN public.prosecutors p ON p.id = ce.prosecutor_id
LEFT JOIN public.staff st ON st.id = ce.staff_id
LEFT JOIN public.courts co ON co.id = ce.court_id
LEFT JOIN public.users vu ON vu.id = ce.voided_by_user_id;

COMMENT ON VIEW public.v_case_timeline IS 'Case details page timeline read model with legacy event status plus split case status and case stage fields.';

GRANT SELECT ON public.case_stages TO authenticated;
GRANT SELECT ON public.case_stage_colors TO authenticated;
GRANT SELECT ON public.case_stage_history TO authenticated;
GRANT SELECT ON public.v_ref_case_stages TO authenticated;
GRANT SELECT ON public.v_case_stage_history_detail TO authenticated;
GRANT SELECT ON public.v_docket_quickdetails TO authenticated;
GRANT SELECT ON public.v_case_details_page TO authenticated;
GRANT SELECT ON public.v_case_timeline TO authenticated;

-- Verification queries for manual migration review:
-- SELECT count(*) AS active_broad_status_count FROM public.case_statuses WHERE is_active AND code IN ('PENDING','FILED','DISMISSED','MIXED_RESULT');
-- SELECT count(*) AS active_case_stage_count FROM public.case_stages WHERE is_active;
-- SELECT cpd.case_id, status.code AS case_status_code, stage.code AS case_stage_code FROM public.case_private_details cpd LEFT JOIN public.case_statuses status ON status.id = cpd.current_case_status_id LEFT JOIN public.case_stages stage ON stage.id = cpd.current_case_stage_id LIMIT 20;
-- SELECT count(*) AS missing_current_case_status FROM public.case_private_details WHERE current_case_status_id IS NULL;
-- SELECT count(*) AS missing_current_case_stage FROM public.case_private_details WHERE current_case_stage_id IS NULL;
-- SELECT code, display_label FROM public.v_ref_case_stages ORDER BY sort_order;

NOTIFY pgrst, 'reload schema';

COMMIT;
