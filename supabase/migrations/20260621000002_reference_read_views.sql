-- Frontend reference/read-only lookup views.
-- Development note: these views intentionally do not add RLS policies,
-- permission filters, or security_invoker while the frontend read refactor is
-- being debugged. Production table/view security will be implemented later.

CREATE OR REPLACE VIEW public.v_ref_docket_types AS
SELECT id, name, prefix, sort_order, is_active, created_at
FROM public.docket_types
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_case_statuses AS
SELECT id, code, display_label, sort_order, is_final, is_milestone, is_active, created_at
FROM public.case_statuses
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_case_classifications AS
SELECT id, display_label, description, is_active, created_at
FROM public.case_classifications
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_participant_roles AS
SELECT id, code, display_label, is_active
FROM public.participant_roles
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_address_types AS
SELECT id, code, display_label, is_active
FROM public.address_types
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_courts AS
SELECT id, code, name, court_type, is_active, created_at, updated_at
FROM public.courts
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_violations AS
SELECT id, reference_code, title, short_label, description, law_reference, is_active, created_by_user_id, created_at, canonical_title
FROM public.violations
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_prosecutors AS
SELECT id, first_name, middle_name, last_name, suffix, full_name, short_name, position_id, is_active, created_at
FROM public.prosecutors
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_ref_users AS
SELECT id, prosecutor_id, staff_id, email, is_active, last_login_at, created_at, updated_at, auth_user_id
FROM public.users
WHERE is_active = true;

CREATE OR REPLACE VIEW public.v_address_suggestions AS
SELECT id, line1, line2, barangay, city, province, region, zip_code, country, latitude, longitude, created_at
FROM public.addresses;

CREATE OR REPLACE VIEW public.v_docket_sequence_lookup AS
SELECT id, docket_type_id, docket_year, next_number, last_issued_number, created_at, updated_at
FROM public.docket_sequence_counters;


CREATE OR REPLACE VIEW public.v_recent_audit_logs AS
SELECT id, actor_user_id, action, entity_type, entity_id, metadata, created_at
FROM public.audit_logs;

CREATE OR REPLACE VIEW public.v_case_assignment_detail AS
SELECT
  ca.*,
  CASE
    WHEN p.id IS NULL THEN NULL
    ELSE jsonb_build_object('full_name', p.full_name, 'short_name', p.short_name)
  END AS prosecutors,
  CASE
    WHEN s.id IS NULL THEN NULL
    ELSE jsonb_build_object('full_name', s.full_name, 'short_name', s.short_name)
  END AS staff
FROM public.case_assignments ca
LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
LEFT JOIN public.staff s ON s.id = ca.staff_id;

CREATE OR REPLACE VIEW public.v_case_status_history_detail AS
SELECT
  csh.*,
  CASE
    WHEN fs.id IS NULL THEN NULL
    ELSE jsonb_build_object('code', fs.code, 'display_label', fs.display_label)
  END AS from_status,
  CASE
    WHEN ts.id IS NULL THEN NULL
    ELSE jsonb_build_object('code', ts.code, 'display_label', ts.display_label)
  END AS to_status
FROM public.case_status_history csh
LEFT JOIN public.case_statuses fs ON fs.id = csh.from_status_id
LEFT JOIN public.case_statuses ts ON ts.id = csh.to_status_id;

COMMENT ON VIEW public.v_ref_docket_types IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_case_statuses IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_case_classifications IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_participant_roles IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_address_types IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_courts IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_violations IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_prosecutors IS 'Frontend reference view; security policies will be implemented later.';
COMMENT ON VIEW public.v_ref_users IS 'Frontend user lookup view; security policies will be implemented later.';
COMMENT ON VIEW public.v_address_suggestions IS 'Frontend address suggestion view; security policies will be implemented later.';
COMMENT ON VIEW public.v_docket_sequence_lookup IS 'Frontend docket-number preview view; security policies will be implemented later.';
COMMENT ON VIEW public.v_recent_audit_logs IS 'Frontend audit-log read view; security policies will be implemented later.';
COMMENT ON VIEW public.v_case_assignment_detail IS 'Frontend case-assignment read view; security policies will be implemented later.';
COMMENT ON VIEW public.v_case_status_history_detail IS 'Frontend case-status-history read view; security policies will be implemented later.';

GRANT SELECT ON
  public.v_docket_shell,
  public.v_docket_participants,
  public.v_docket_quickdetails,
  public.v_docket_case_violation_classification,
  public.v_docket_case_labels,
  public.v_case_details_page,
  public.v_case_timeline,
  public.v_case_participants_detail,
  public.v_case_attachments,
  public.v_case_courts_detail,
  public.v_case_motions_detail,
  public.v_case_petitions_for_review_detail,
  public.v_clearance_participant_attributes,
  public.v_person_details,
  public.v_ref_docket_types,
  public.v_ref_case_statuses,
  public.v_ref_case_classifications,
  public.v_ref_participant_roles,
  public.v_ref_address_types,
  public.v_ref_courts,
  public.v_ref_violations,
  public.v_ref_prosecutors,
  public.v_ref_users,
  public.v_address_suggestions,
  public.v_docket_sequence_lookup,
  public.v_recent_audit_logs,
  public.v_case_assignment_detail,
  public.v_case_status_history_detail
TO authenticated;

NOTIFY pgrst, 'reload schema';
