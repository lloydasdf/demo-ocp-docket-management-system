CREATE OR REPLACE VIEW public.v_ref_case_event_types AS
SELECT id, code, display_label, category, description, sort_order, is_active
FROM public.case_event_types
WHERE is_active = true;

COMMENT ON VIEW public.v_ref_case_event_types IS 'Frontend reference view for active case timeline/activity event types.';

GRANT ALL ON TABLE public.v_ref_case_event_types TO anon;
GRANT ALL ON TABLE public.v_ref_case_event_types TO authenticated;
GRANT ALL ON TABLE public.v_ref_case_event_types TO service_role;
