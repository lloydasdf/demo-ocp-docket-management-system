-- Make the docket RPC and its retry record one transaction. The existing docket RPCs
-- remain unchanged and are called by this wrapper.
CREATE OR REPLACE FUNCTION public.create_docket_entry_idempotent(
  p_payload jsonb,
  p_idempotency_key uuid,
  p_linked_pe_case_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_request public.docket_creation_requests%ROWTYPE;
  v_result jsonb;
  v_case_id bigint;
  v_candidate_count integer;
BEGIN
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501'; END IF;

  -- Serializes this user's key, including stale-claim recovery and concurrent retries.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_auth_uid::text || ':' || p_idempotency_key::text, 0));

  SELECT * INTO v_request
  FROM public.docket_creation_requests
  WHERE auth_user_id = v_auth_uid AND idempotency_key = p_idempotency_key
  FOR UPDATE;

  IF v_request.result IS NOT NULL THEN RETURN v_request.result; END IF;

  IF v_request.case_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'caseId', c.id, 'docketTypeId', c.docket_type_id, 'docketYear', c.docket_year,
      'docketNumber', c.docket_number, 'docketMonthCode', c.docket_month_code,
      'docketDisplayNumber', concat_ws('-', c.region_code, dt.prefix,
        right(c.docket_year::text, 2) || coalesce(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0'))
    ) INTO v_result FROM public.cases c JOIN public.docket_types dt ON dt.id = c.docket_type_id
    WHERE c.id = v_request.case_id;
    IF v_result IS NOT NULL THEN
      UPDATE public.docket_creation_requests SET status='CREATED', result=v_result, updated_at=now()
      WHERE auth_user_id=v_auth_uid AND idempotency_key=p_idempotency_key;
      RETURN v_result;
    END IF;
  END IF;

  IF v_request.status = 'CREATING' AND v_request.updated_at > now() - interval '2 minutes' THEN
    RAISE EXCEPTION 'DOCKET_CREATION_IN_PROGRESS' USING ERRCODE = 'P0001';
  END IF;

  -- Recover claims written by the old, non-atomic endpoint. If its RPC committed
  -- before the process died, the earliest matching case after the claim is reused.
  IF v_request.status = 'CREATING' THEN
    SELECT count(*), min(c.id) INTO v_candidate_count, v_case_id
    FROM public.cases c
    JOIN public.users u ON u.id = c.created_by_user_id
    WHERE u.auth_user_id = v_auth_uid
      AND c.created_at >= v_request.created_at - interval '1 second'
      AND c.docket_type_id = nullif(p_payload->>'docketTypeId','')::bigint
      AND c.docket_year = nullif(p_payload->>'docketYear','')::integer
      AND c.date_received = nullif(p_payload->>'dateReceived','')::date;

    IF v_candidate_count > 0 THEN
      SELECT jsonb_build_object(
        'caseId', c.id, 'docketTypeId', c.docket_type_id, 'docketYear', c.docket_year,
        'docketNumber', c.docket_number, 'docketMonthCode', c.docket_month_code,
        'docketDisplayNumber', concat_ws('-', c.region_code, dt.prefix,
          right(c.docket_year::text, 2) || coalesce(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0'))
      ) INTO v_result FROM public.cases c JOIN public.docket_types dt ON dt.id=c.docket_type_id WHERE c.id=v_case_id;
      UPDATE public.docket_creation_requests SET status='CREATED', case_id=v_case_id, result=v_result, updated_at=now()
      WHERE auth_user_id=v_auth_uid AND idempotency_key=p_idempotency_key;
      RETURN v_result;
    END IF;

    DELETE FROM public.docket_creation_requests
    WHERE auth_user_id=v_auth_uid AND idempotency_key=p_idempotency_key;
  END IF;

  INSERT INTO public.docket_creation_requests(auth_user_id,idempotency_key,status,updated_at)
  VALUES(v_auth_uid,p_idempotency_key,'CREATING',now());

  IF p_linked_pe_case_id IS NULL THEN
    v_result := public.create_new_docket_entry(p_payload);
  ELSE
    v_result := public.create_linked_docket_entry(p_payload,p_linked_pe_case_id);
  END IF;

  v_case_id := nullif(v_result->>'caseId','')::bigint;
  UPDATE public.docket_creation_requests
  SET status='CREATED', case_id=v_case_id, result=v_result, updated_at=now()
  WHERE auth_user_id=v_auth_uid AND idempotency_key=p_idempotency_key;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.create_docket_entry_idempotent(jsonb,uuid,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_docket_entry_idempotent(jsonb,uuid,bigint) TO authenticated;
