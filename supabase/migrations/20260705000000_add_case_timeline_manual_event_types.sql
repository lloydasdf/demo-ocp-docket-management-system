INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
VALUES
  ('CASE_ASSIGNMENT', 'Case Assignment', 'CASE', 'Manual timeline event for assigning a case.', 100, true, true),
  ('CASE_REASSIGNMENT', 'Case Reassignment', 'CASE', 'Manual timeline event for reassigning a case.', 110, true, true),
  ('CASE_RESOLVED', 'Case Resolved', 'CASE', 'Manual timeline event for resolving a case.', 120, true, true),
  ('CASE_DECISION_APPROVED', 'Case Decision Approved', 'CASE', 'Manual timeline event for approval of a case decision.', 130, true, true),
  ('COURT_FILING', 'Court Filing', 'COURT', 'Manual timeline event for filing a case in court.', 200, true, true),
  ('COURT_STATUS_UPDATE', 'Court Status Update', 'COURT', 'Manual timeline event for court status changes.', 210, true, true),
  ('MOTION_RECEIVED', 'Motion Received', 'MOTION', 'Manual timeline event for receipt of a motion.', 300, true, true),
  ('MOTION_RESOLVED', 'Motion Resolved', 'MOTION', 'Manual timeline event for resolution of a motion.', 310, true, true),
  ('MOTION_DECISION_APPROVED', 'Motion Decision Approved', 'MOTION', 'Manual timeline event for approval of a motion decision.', 320, true, true),
  ('PETITION_FOR_REVIEW', 'Petition for Review', 'PETITION', 'Manual timeline event for a petition for review.', 400, true, true),
  ('CUSTOM_EVENT', 'Custom Event', 'GENERAL', 'Manual custom timeline event.', 900, true, true),
  ('ADD_EVENT_TYPE', 'Add Event Type', 'GENERAL', 'Manual timeline event for adding an event type.', 910, true, true)
ON CONFLICT (code) DO UPDATE SET
  display_label = EXCLUDED.display_label,
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  updated_at = now();
