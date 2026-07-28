CREATE TABLE public.drive_document_edit_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id bigint NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  gdrive_file_id varchar(255) NOT NULL,
  file_name text NOT NULL,
  mime_type text NOT NULL,
  actor_auth_user_id uuid NOT NULL,
  actor_user_id bigint REFERENCES public.users(id),
  editor_access_token uuid NOT NULL DEFAULT gen_random_uuid(),
  expected_modified_time timestamptz,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SAVED','CLOSED','FAILED','EXPIRED')),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '2 hours',
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX drive_document_single_editor_idx ON public.drive_document_edit_sessions(gdrive_file_id) WHERE status = 'ACTIVE';
CREATE INDEX drive_document_edit_case_idx ON public.drive_document_edit_sessions(case_id, created_at DESC);
ALTER TABLE public.drive_document_edit_sessions ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.drive_document_edit_sessions TO service_role;
REVOKE ALL ON public.drive_document_edit_sessions FROM anon, authenticated;
