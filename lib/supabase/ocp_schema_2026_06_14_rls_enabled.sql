--
-- PostgreSQL database dump
--

\restrict qnRWCXRPfxj7eilPJJnMSoFcVMsbrDKvaGZAA2xeOb6EkAUYrHuLeaxq6f31eHf

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
begin
    if not exists (
        select 1
        from pg_event_trigger_ddl_commands() ev
        join pg_catalog.pg_extension e on ev.objid = e.oid
        where e.extname = 'pg_graphql'
    ) then
        return;
    end if;

    drop function if exists graphql_public.graphql;
    create or replace function graphql_public.graphql(
        "operationName" text default null,
        query text default null,
        variables jsonb default null,
        extensions jsonb default null
    )
        returns jsonb
        language sql
    as $$
        select graphql.resolve(
            query := query,
            variables := coalesce(variables, '{}'),
            "operationName" := "operationName",
            extensions := extensions
        );
    $$;

    -- Attach the wrapper to the extension so DROP EXTENSION cascades to it,
    -- which in turn triggers set_graphql_placeholder to reinstall the "not enabled" stub.
    alter extension pg_graphql add function graphql_public.graphql(text, text, jsonb, jsonb);

    grant usage on schema graphql to postgres, anon, authenticated, service_role;
    grant execute on function graphql.resolve to postgres, anon, authenticated, service_role;
    grant usage on schema graphql to postgres with grant option;
    grant usage on schema graphql_public to postgres with grant option;
end;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: graphql(text, text, jsonb, jsonb); Type: FUNCTION; Schema: graphql_public; Owner: -
--

CREATE FUNCTION graphql_public.graphql("operationName" text DEFAULT NULL::text, query text DEFAULT NULL::text, variables jsonb DEFAULT NULL::jsonb, extensions jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
  BEGIN
      RAISE DEBUG 'PgBouncer auth request: %', p_usename;

      RETURN QUERY
      SELECT
          rolname::text,
          CASE WHEN rolvaliduntil < now()
              THEN null
              ELSE rolpassword::text
          END
      FROM pg_authid
      WHERE rolname=$1 and rolcanlogin;
  END;
  $_$;


--
-- Name: apply_clearance_common_name_variants_to_possible_tokens(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_clearance_common_name_variants_to_possible_tokens() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Remove old generated common-name variant rows first
  DELETE FROM public.clearance_possible_name_tokens
  WHERE source_column = 'common_name_variant';

  -- Add generated MA/MARIA variant tokens
  INSERT INTO public.clearance_possible_name_tokens (
    person_id,
    source_table,
    source_column,
    source_value,
    token,
    token_order,
    token_len,
    first_char,
    first2,
    first3,
    last2,
    last3,
    ck_key,
    bv_key,
    phf_key,
    sz_key,
    skeleton
  )
  SELECT
    base.person_id,
    base.source_table,
    'common_name_variant',
    base.source_value,
    variant_token,
    base.token_order,
    length(variant_token),
    left(variant_token, 1),
    left(variant_token, 2),
    left(variant_token, 3),
    right(variant_token, 2),
    right(variant_token, 3),
    public.clearance_ck_key(variant_token),
    public.clearance_bv_key(variant_token),
    public.clearance_phf_key(variant_token),
    public.clearance_sz_key(variant_token),
    public.clearance_token_skeleton(variant_token)
  FROM public.clearance_possible_name_tokens base
  CROSS JOIN LATERAL unnest(public.clearance_common_name_variants(base.token)) AS v(variant_token)
  WHERE base.source_column <> 'common_name_variant'
    AND variant_token <> base.token;
END;
$$;


--
-- Name: can_assign_case(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_assign_case() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN']);
$$;


--
-- Name: can_assign_role(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_assign_role(p_target_role_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    CASE
      WHEN upper(p_target_role_code) = 'DEVELOPER'
        THEN public.has_app_role('DEVELOPER')
      ELSE
        public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN'])
    END;
$$;


--
-- Name: can_create_case(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_create_case() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN']);
$$;


--
-- Name: can_delete_case(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_delete_case() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('DEVELOPER');
$$;


--
-- Name: can_delete_seed_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_delete_seed_data() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('DEVELOPER');
$$;


--
-- Name: can_edit_case_details(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_edit_case_details(p_case_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN'])
    OR (
      public.has_any_app_role(ARRAY['PROSECUTOR', 'STAFF'])
      AND public.can_view_case_details(p_case_id)
    );
$$;


--
-- Name: can_edit_case_header(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_edit_case_header() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN']);
$$;


--
-- Name: can_edit_case_participant_details(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_edit_case_participant_details(p_case_participant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.case_participants cp
    WHERE cp.id = p_case_participant_id
      AND public.can_edit_case_details(cp.case_id)
  );
$$;


--
-- Name: can_manage_master_identity_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_master_identity_data() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN']);
$$;


--
-- Name: can_manage_seed_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_seed_data() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN']);
$$;


--
-- Name: can_manage_system_internal(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_system_internal() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('DEVELOPER');
$$;


--
-- Name: can_manage_users(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_users() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN']);
$$;


--
-- Name: can_view_address_details(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_address_details(p_address_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    EXISTS (
      SELECT 1
      FROM public.case_addresses ca
      WHERE ca.address_id = p_address_id
        AND public.can_view_case_details(ca.case_id)
    )
    OR EXISTS (
      SELECT 1
      FROM public.person_addresses pa
      JOIN public.case_participants cp
        ON cp.person_id = pa.person_id
      WHERE pa.address_id = p_address_id
        AND public.can_view_case_details(cp.case_id)
    );
$$;


--
-- Name: can_view_audit_logs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_audit_logs() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF']);
$$;


--
-- Name: can_view_case_details(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_case_details(p_case_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN'])

    OR (
      public.has_app_role('PROSECUTOR')
      AND EXISTS (
        SELECT 1
        FROM public.case_assignments ca
        WHERE ca.case_id = p_case_id
          AND ca.unassigned_at IS NULL
          AND ca.prosecutor_id = public.current_app_prosecutor_id()
      )
    )

    OR (
      public.has_app_role('STAFF')
      AND EXISTS (
        SELECT 1
        FROM public.case_assignments ca
        WHERE ca.case_id = p_case_id
          AND ca.unassigned_at IS NULL
          AND (
            ca.staff_id = public.current_app_staff_id()

            OR EXISTS (
              SELECT 1
              FROM public.prosecutor_staff_assignments psa
              WHERE psa.prosecutor_id = ca.prosecutor_id
                AND psa.staff_id = public.current_app_staff_id()
                AND psa.is_active = true
                AND psa.start_date <= CURRENT_DATE
                AND (
                  psa.end_date IS NULL
                  OR psa.end_date >= CURRENT_DATE
                )
            )
          )
      )
    );
$$;


--
-- Name: can_view_case_participant_details(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_case_participant_details(p_case_participant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.case_participants cp
    WHERE cp.id = p_case_participant_id
      AND public.can_view_case_details(cp.case_id)
  );
$$;


--
-- Name: can_view_organization_details(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_organization_details(p_organization_id integer) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.case_participants cp
    WHERE cp.organization_id = p_organization_id
      AND public.can_view_case_details(cp.case_id)
  );
$$;


--
-- Name: can_view_person_details(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_person_details(p_person_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.case_participants cp
    WHERE cp.person_id = p_person_id
      AND public.can_view_case_details(cp.case_id)
  );
$$;


--
-- Name: clearance_bv_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_bv_key(input_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH x AS (
    SELECT public.clearance_exact_norm(input_text) AS n
  )
  SELECT
    CASE
      WHEN left(n, 1) IN ('B', 'V') AND length(n) >= 3
        THEN 'B' || substring(n FROM 2)
      ELSE n
    END
  FROM x;
$$;


--
-- Name: clearance_ck_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_ck_key(input_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH x AS (
    SELECT public.clearance_exact_norm(input_text) AS n
  )
  SELECT
    CASE
      WHEN left(n, 1) IN ('C', 'K') AND length(n) >= 3
        THEN 'K' || substring(n FROM 2)
      ELSE n
    END
  FROM x;
$$;


--
-- Name: clearance_common_name_variants(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_common_name_variants(input_text text) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH n AS (
    SELECT public.clearance_exact_norm(input_text) AS token
  )
  SELECT
    CASE
      WHEN token = 'MA' THEN ARRAY['MARIA']::text[]
      WHEN token = 'MARIA' THEN ARRAY['MA']::text[]
      ELSE ARRAY[]::text[]
    END
  FROM n;
$$;


--
-- Name: clearance_edit_distance_limit(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_edit_distance_limit(input_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH x AS (
    SELECT length(public.clearance_exact_norm(input_text)) AS len
  )
  SELECT
    CASE
      WHEN len BETWEEN 3 AND 5 THEN 1
      WHEN len BETWEEN 6 AND 9 THEN 2
      WHEN len >= 10 THEN 2
      ELSE 0
    END
  FROM x;
$$;


--
-- Name: clearance_exact_norm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_exact_norm(input_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT trim(
    regexp_replace(
      regexp_replace(
        upper(translate(coalesce(input_text, ''), 'Ññ', 'Nn')),
        '[^A-Z0-9 ]+',
        ' ',
        'g'
      ),
      '\s+',
      ' ',
      'g'
    )
  );
$$;


--
-- Name: clearance_exact_tokens(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_exact_tokens(input_text text) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT coalesce(array_agg(token ORDER BY token), array[]::text[])
  FROM regexp_split_to_table(public.clearance_exact_norm(input_text), ' ') AS token
  WHERE length(token) > 1;
$$;


--
-- Name: clearance_phf_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_phf_key(input_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT replace(public.clearance_exact_norm(input_text), 'PH', 'F');
$$;


--
-- Name: clearance_phonetic_codes(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_phonetic_codes(input_text text) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH normalized AS (
    SELECT public.clearance_exact_norm(input_text) AS token
  ),
  codes AS (
    SELECT dmetaphone(token) AS code FROM normalized
    UNION
    SELECT dmetaphone_alt(token) AS code FROM normalized
  )
  SELECT coalesce(array_agg(DISTINCT code), array[]::text[])
  FROM codes
  WHERE code IS NOT NULL
    AND code <> '';
$$;


--
-- Name: clearance_possible_token_score_v3(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_possible_token_score_v3(query_token text, record_token text) RETURNS numeric
    LANGUAGE sql STABLE
    AS $$
  WITH x AS (
    SELECT
      public.clearance_exact_norm(query_token) AS q,
      public.clearance_exact_norm(record_token) AS r
  ),
  prepared AS (
    SELECT
      q,
      r,
      public.clearance_ck_key(q) AS q_ck,
      public.clearance_ck_key(r) AS r_ck,
      public.clearance_bv_key(q) AS q_bv,
      public.clearance_bv_key(r) AS r_bv,
      public.clearance_phf_key(q) AS q_phf,
      public.clearance_phf_key(r) AS r_phf,
      public.clearance_sz_key(q) AS q_sz,
      public.clearance_sz_key(r) AS r_sz,
      least(
        public.clearance_edit_distance_limit(q),
        public.clearance_edit_distance_limit(r)
      ) AS max_d
    FROM x
  ),
  scored AS (
    SELECT
      q,
      r,
      q_ck,
      r_ck,
      q_bv,
      r_bv,
      q_phf,
      r_phf,
      q_sz,
      r_sz,
      max_d,

      CASE
        WHEN max_d > 0 THEN levenshtein_less_equal(q, r, max_d)
        ELSE 99
      END AS raw_distance,

      CASE
        WHEN max_d > 0 THEN levenshtein_less_equal(q_ck, r_ck, max_d)
        ELSE 99
      END AS ck_distance,

      CASE
        WHEN max_d > 0 THEN levenshtein_less_equal(q_bv, r_bv, max_d)
        ELSE 99
      END AS bv_distance,

      CASE
        WHEN max_d > 0 THEN levenshtein_less_equal(q_phf, r_phf, max_d)
        ELSE 99
      END AS phf_distance,

      CASE
        WHEN max_d > 0 THEN levenshtein_less_equal(q_sz, r_sz, max_d)
        ELSE 99
      END AS sz_distance,

      greatest(
        similarity(q, r),
        similarity(q_ck, r_ck),
        similarity(q_bv, r_bv),
        similarity(q_phf, r_phf),
        similarity(q_sz, r_sz)
      ) AS best_similarity

    FROM prepared
  ),
  final AS (
    SELECT
      *,
      least(raw_distance, ck_distance, bv_distance, phf_distance, sz_distance) AS best_edit_distance,

      CASE
        WHEN q = '' OR r = '' THEN false

        -- raw near-prefix: JOAN -> JOANNE
        WHEN length(q) >= 3
          AND length(r) > length(q)
          AND length(r) - length(q) <= 2
          AND left(r, length(q)) = q
          THEN true

        WHEN length(r) >= 3
          AND length(q) > length(r)
          AND length(q) - length(r) <= 2
          AND left(q, length(r)) = r
          THEN true

        -- C/K near-prefix
        WHEN length(q_ck) >= 3
          AND length(r_ck) > length(q_ck)
          AND length(r_ck) - length(q_ck) <= 2
          AND left(r_ck, length(q_ck)) = q_ck
          THEN true

        WHEN length(r_ck) >= 3
          AND length(q_ck) > length(r_ck)
          AND length(q_ck) - length(r_ck) <= 2
          AND left(q_ck, length(r_ck)) = r_ck
          THEN true

        -- B/V near-prefix
        WHEN length(q_bv) >= 3
          AND length(r_bv) > length(q_bv)
          AND length(r_bv) - length(q_bv) <= 2
          AND left(r_bv, length(q_bv)) = q_bv
          THEN true

        WHEN length(r_bv) >= 3
          AND length(q_bv) > length(r_bv)
          AND length(q_bv) - length(r_bv) <= 2
          AND left(q_bv, length(r_bv)) = r_bv
          THEN true

        -- PH/F near-prefix
        WHEN length(q_phf) >= 3
          AND length(r_phf) > length(q_phf)
          AND length(r_phf) - length(q_phf) <= 2
          AND left(r_phf, length(q_phf)) = q_phf
          THEN true

        WHEN length(r_phf) >= 3
          AND length(q_phf) > length(r_phf)
          AND length(q_phf) - length(r_phf) <= 2
          AND left(q_phf, length(r_phf)) = r_phf
          THEN true

        -- S/Z near-prefix
        WHEN length(q_sz) >= 3
          AND length(r_sz) > length(q_sz)
          AND length(r_sz) - length(q_sz) <= 2
          AND left(r_sz, length(q_sz)) = q_sz
          THEN true

        WHEN length(r_sz) >= 3
          AND length(q_sz) > length(r_sz)
          AND length(q_sz) - length(r_sz) <= 2
          AND left(q_sz, length(r_sz)) = r_sz
          THEN true

        ELSE false
      END AS is_near_prefix

    FROM scored
  )
  SELECT
    CASE
      WHEN q = '' OR r = '' THEN 0

      -- Exact token
      WHEN q = r THEN 1.00

      -- Exact after simple spelling-variant normalization
      WHEN q_ck = r_ck AND q <> r THEN 0.90
      WHEN q_bv = r_bv AND q <> r THEN 0.90
      WHEN q_sz = r_sz AND q <> r THEN 0.90
      WHEN q_phf = r_phf AND q <> r THEN 0.88

      -- Name short form / near-prefix:
      -- JOAN -> JOANNE, ANN -> ANNE, etc.
      WHEN is_near_prefix THEN
        CASE
          WHEN abs(length(q) - length(r)) <= 1 THEN 0.86
          ELSE 0.80
        END

      -- Edit-distance typo matching
      WHEN max_d > 0 AND best_edit_distance <= max_d THEN
        CASE
          WHEN best_edit_distance = 1 THEN 0.86
          WHEN best_edit_distance = 2 THEN 0.76
          ELSE 0.70
        END

      -- Trigram similarity for longer tokens
      WHEN length(q) >= 4
        AND length(r) >= 4
        AND best_similarity >= 0.60
        THEN best_similarity

      ELSE 0
    END
  FROM final;
$$;


--
-- Name: clearance_sz_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_sz_key(input_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH x AS (
    SELECT public.clearance_exact_norm(input_text) AS n
  )
  SELECT
    CASE
      WHEN left(n, 1) IN ('S', 'Z') AND length(n) >= 3
        THEN 'S' || substring(n FROM 2)
      ELSE n
    END
  FROM x;
$$;


--
-- Name: clearance_token_match_score(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_token_match_score(query_token text, record_token text) RETURNS numeric
    LANGUAGE sql STABLE
    AS $$
  WITH x AS (
    SELECT
      public.clearance_exact_norm(query_token) AS q,
      public.clearance_exact_norm(record_token) AS r
  )
  SELECT
    CASE
      WHEN q = '' OR r = '' THEN 0
      WHEN q = r THEN 1.00
      WHEN public.clearance_token_variant_equal(q, r) THEN 0.90
      WHEN length(q) >= 4
        AND length(r) >= 4
        AND similarity(q, r) >= 0.60
        THEN greatest(0.60, similarity(q, r))
      ELSE 0
    END
  FROM x;
$$;


--
-- Name: clearance_token_skeleton(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_token_skeleton(input_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH x AS (
    SELECT public.clearance_exact_norm(input_text) AS n
  )
  SELECT
    CASE
      WHEN length(n) <= 2 THEN n
      ELSE left(n, 1) || regexp_replace(substring(n FROM 2), '[AEIOUHY]+', '', 'g')
    END
  FROM x;
$$;


--
-- Name: clearance_token_variant_equal(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clearance_token_variant_equal(a text, b text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  WITH x AS (
    SELECT
      public.clearance_exact_norm(a) AS aa,
      public.clearance_exact_norm(b) AS bb
  )
  SELECT
    aa = bb
    OR (
      length(aa) >= 3
      AND length(bb) >= 3
      AND substring(aa from 2) = substring(bb from 2)
      AND left(aa, 1) IN ('C', 'K')
      AND left(bb, 1) IN ('C', 'K')
    )
    OR (
      length(aa) >= 3
      AND length(bb) >= 3
      AND substring(aa from 2) = substring(bb from 2)
      AND left(aa, 1) IN ('B', 'V')
      AND left(bb, 1) IN ('B', 'V')
    )
    OR replace(aa, 'PH', 'F') = replace(bb, 'PH', 'F')
  FROM x;
$$;


--
-- Name: create_case_event(bigint, text, date, text, text, jsonb, bigint, time without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_case_event(p_case_id bigint, p_event_type_code text, p_event_date date, p_title text, p_description text DEFAULT NULL::text, p_details_jsonb jsonb DEFAULT '{}'::jsonb, p_created_by_user_id bigint DEFAULT NULL::bigint, p_event_time time without time zone DEFAULT NULL::time without time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_event_type_id bigint;
    v_event_id bigint;
BEGIN
    SELECT id INTO v_event_type_id
    FROM public.case_event_types
    WHERE code = p_event_type_code
      AND is_active = true;

    IF v_event_type_id IS NULL THEN
        RAISE EXCEPTION 'Unknown or inactive case event type: %', p_event_type_code;
    END IF;

    INSERT INTO public.case_events (
        case_id,
        event_type_id,
        event_date,
        event_time,
        title,
        description,
        details_jsonb,
        source,
        created_by_user_id,
        updated_by_user_id
    )
    VALUES (
        p_case_id,
        v_event_type_id,
        p_event_date,
        p_event_time,
        p_title,
        p_description,
        COALESCE(p_details_jsonb, '{}'::jsonb),
        'USER',
        p_created_by_user_id,
        p_created_by_user_id
    )
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$;


--
-- Name: current_app_prosecutor_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_app_prosecutor_id() RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT u.prosecutor_id
  FROM public.users u
  WHERE u.auth_user_id = auth.uid()
    AND u.is_active = true
  LIMIT 1;
$$;


--
-- Name: current_app_staff_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_app_staff_id() RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT u.staff_id
  FROM public.users u
  WHERE u.auth_user_id = auth.uid()
    AND u.is_active = true
  LIMIT 1;
$$;


--
-- Name: current_app_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_app_user_id() RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT u.id
  FROM public.users u
  WHERE u.auth_user_id = auth.uid()
    AND u.is_active = true
  LIMIT 1;
$$;


--
-- Name: dc2025_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: dc2025_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: dc2025_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.dc2025_split_lines_raw(p_text);
$$;


--
-- Name: dc2025_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.dc2025_nullif_legacy_null(value)
    FROM public.dc2025_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: dc2025_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.dc2025_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: dc2025_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: dc2025_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: dc2025_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.dc2025_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: dc2025_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.dc2025_clean_line(p_text)
    END;
$$;


--
-- Name: dc2025_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.dc2025_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.dc2025_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.dc2025_clean_line(p_text)
    END;
$$;


--
-- Name: dc2025_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: dc2025_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: dc2025_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.dc2025_nullif_legacy_null(value) AS value
    FROM public.dc2025_split_lines_raw(p_text)
    WHERE public.dc2025_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: dc2025_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.dc2025_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.dc2025_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: dc2025_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.dc2025_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.dc2025_nullif_legacy_null(public.dc2025_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: dc2025_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.dc2025_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: dc2025_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dc2025_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.dc2025_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: has_any_app_role(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_any_app_role(p_role_codes text[]) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.user_roles ur
      ON ur.user_id = u.id
    JOIN public.roles r
      ON r.id = ur.role_id
    WHERE u.auth_user_id = auth.uid()
      AND u.is_active = true
      AND r.is_active = true
      AND upper(r.code) = ANY (
        SELECT upper(code)
        FROM unnest(p_role_codes) AS code
      )
  );
$$;


--
-- Name: has_app_role(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_app_role(p_role_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.user_roles ur
      ON ur.user_id = u.id
    JOIN public.roles r
      ON r.id = ur.role_id
    WHERE u.auth_user_id = auth.uid()
      AND u.is_active = true
      AND r.is_active = true
      AND upper(r.code) = upper(p_role_code)
  );
$$;


--
-- Name: inq2022_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inq2022_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inq2022_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inq2022_split_lines_raw(p_text);
$$;


--
-- Name: inq2022_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2022_nullif_legacy_null(value)
    FROM public.inq2022_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2022_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inq2022_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2022_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inq2022_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inq2022_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2022_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inq2022_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inq2022_clean_line(p_text)
    END;
$$;


--
-- Name: inq2022_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inq2022_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inq2022_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inq2022_clean_line(p_text)
    END;
$$;


--
-- Name: inq2022_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inq2022_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inq2022_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inq2022_nullif_legacy_null(value) AS value
    FROM public.inq2022_split_lines_raw(p_text)
    WHERE public.inq2022_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inq2022_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2022_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2022_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inq2022_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2022_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2022_nullif_legacy_null(public.inq2022_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inq2022_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2022_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inq2022_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2022_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inq2022_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inq2023_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inq2023_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inq2023_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inq2023_split_lines_raw(p_text);
$$;


--
-- Name: inq2023_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2023_nullif_legacy_null(value)
    FROM public.inq2023_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2023_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inq2023_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2023_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inq2023_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inq2023_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2023_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inq2023_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inq2023_clean_line(p_text)
    END;
$$;


--
-- Name: inq2023_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inq2023_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inq2023_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inq2023_clean_line(p_text)
    END;
$$;


--
-- Name: inq2023_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inq2023_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inq2023_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inq2023_nullif_legacy_null(value) AS value
    FROM public.inq2023_split_lines_raw(p_text)
    WHERE public.inq2023_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inq2023_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2023_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2023_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inq2023_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2023_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2023_nullif_legacy_null(public.inq2023_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inq2023_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2023_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inq2023_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2023_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inq2023_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inq2024_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inq2024_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inq2024_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inq2024_split_lines_raw(p_text);
$$;


--
-- Name: inq2024_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2024_nullif_legacy_null(value)
    FROM public.inq2024_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2024_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inq2024_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2024_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inq2024_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inq2024_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2024_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inq2024_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inq2024_clean_line(p_text)
    END;
$$;


--
-- Name: inq2024_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inq2024_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inq2024_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inq2024_clean_line(p_text)
    END;
$$;


--
-- Name: inq2024_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inq2024_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inq2024_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inq2024_nullif_legacy_null(value) AS value
    FROM public.inq2024_split_lines_raw(p_text)
    WHERE public.inq2024_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inq2024_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2024_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2024_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inq2024_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2024_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2024_nullif_legacy_null(public.inq2024_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inq2024_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2024_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inq2024_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2024_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inq2024_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inq2025_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inq2025_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inq2025_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inq2025_split_lines_raw(p_text);
$$;


--
-- Name: inq2025_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2025_nullif_legacy_null(value)
    FROM public.inq2025_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2025_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inq2025_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inq2025_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inq2025_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inq2025_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2025_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inq2025_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inq2025_clean_line(p_text)
    END;
$$;


--
-- Name: inq2025_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inq2025_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inq2025_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inq2025_clean_line(p_text)
    END;
$$;


--
-- Name: inq2025_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inq2025_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inq2025_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inq2025_nullif_legacy_null(value) AS value
    FROM public.inq2025_split_lines_raw(p_text)
    WHERE public.inq2025_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inq2025_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2025_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2025_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inq2025_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inq2025_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inq2025_nullif_legacy_null(public.inq2025_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inq2025_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inq2025_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inq2025_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inq2025_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inq2025_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inv2022_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inv2022_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inv2022_line_count(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_line_count(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inv2022_split_lines(p_text);
$$;


--
-- Name: inv2022_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inv2022_split_lines(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2022_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inv2022_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inv2022_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2022_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inv2022_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inv2022_clean_line(p_text)
    END;
$$;


--
-- Name: inv2022_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*([0-9]+)'), '')::integer;
$$;


--
-- Name: inv2022_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inv2022_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2022_strip_trailing_comma(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2022_strip_trailing_comma(raw_line) IS NOT NULL;
$$;


--
-- Name: inv2022_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2022_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2022_strip_person_number(raw_line) IS NOT NULL;
$$;


--
-- Name: inv2022_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2022_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inv2022_strip_trailing_comma(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_strip_trailing_comma(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT public.inv2022_clean_line(regexp_replace(coalesce(p_text, ''), '\s*[,;]+\s*$', '', 'g'));
$_$;


--
-- Name: inv2022_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := nullif(trim(coalesce(p_text, '')), '');
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    -- Excel serial date fallback.
    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inv2022b_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inv2022b_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inv2022b_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inv2022b_split_lines_raw(p_text);
$$;


--
-- Name: inv2022b_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2022b_nullif_legacy_null(value)
    FROM public.inv2022b_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2022b_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inv2022b_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2022b_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inv2022b_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inv2022b_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2022b_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inv2022b_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inv2022b_clean_line(p_text)
    END;
$$;


--
-- Name: inv2022b_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inv2022b_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inv2022b_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inv2022b_clean_line(p_text)
    END;
$$;


--
-- Name: inv2022b_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inv2022b_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inv2022b_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inv2022b_nullif_legacy_null(value) AS value
    FROM public.inv2022b_split_lines_raw(p_text)
    WHERE public.inv2022b_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inv2022b_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2022b_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2022b_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inv2022b_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2022b_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2022b_nullif_legacy_null(public.inv2022b_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inv2022b_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2022b_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inv2022b_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2022b_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inv2022b_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inv2023_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inv2023_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inv2023_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inv2023_split_lines_raw(p_text);
$$;


--
-- Name: inv2023_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2023_nullif_legacy_null(value)
    FROM public.inv2023_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2023_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inv2023_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2023_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inv2023_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inv2023_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2023_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inv2023_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inv2023_clean_line(p_text)
    END;
$$;


--
-- Name: inv2023_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inv2023_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inv2023_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inv2023_clean_line(p_text)
    END;
$$;


--
-- Name: inv2023_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inv2023_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inv2023_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inv2023_nullif_legacy_null(value) AS value
    FROM public.inv2023_split_lines_raw(p_text)
    WHERE public.inv2023_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inv2023_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2023_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2023_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inv2023_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2023_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2023_nullif_legacy_null(public.inv2023_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inv2023_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2023_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inv2023_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2023_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inv2023_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inv2024_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inv2024_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inv2024_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inv2024_split_lines_raw(p_text);
$$;


--
-- Name: inv2024_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2024_nullif_legacy_null(value)
    FROM public.inv2024_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2024_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inv2024_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2024_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inv2024_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inv2024_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2024_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inv2024_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inv2024_clean_line(p_text)
    END;
$$;


--
-- Name: inv2024_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inv2024_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inv2024_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inv2024_clean_line(p_text)
    END;
$$;


--
-- Name: inv2024_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inv2024_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inv2024_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inv2024_nullif_legacy_null(value) AS value
    FROM public.inv2024_split_lines_raw(p_text)
    WHERE public.inv2024_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inv2024_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2024_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2024_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inv2024_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2024_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2024_nullif_legacy_null(public.inv2024_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inv2024_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2024_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inv2024_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2024_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inv2024_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inv2025_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: inv2025_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: inv2025_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.inv2025_split_lines_raw(p_text);
$$;


--
-- Name: inv2025_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2025_nullif_legacy_null(value)
    FROM public.inv2025_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2025_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.inv2025_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: inv2025_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: inv2025_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: inv2025_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2025_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: inv2025_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.inv2025_clean_line(p_text)
    END;
$$;


--
-- Name: inv2025_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.inv2025_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.inv2025_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.inv2025_clean_line(p_text)
    END;
$$;


--
-- Name: inv2025_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: inv2025_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: inv2025_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.inv2025_nullif_legacy_null(value) AS value
    FROM public.inv2025_split_lines_raw(p_text)
    WHERE public.inv2025_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: inv2025_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2025_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2025_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: inv2025_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.inv2025_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.inv2025_nullif_legacy_null(public.inv2025_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: inv2025_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.inv2025_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: inv2025_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv2025_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.inv2025_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: inv22_compare_norm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv22_compare_norm(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(
        regexp_replace(
            upper(
                btrim(
                    regexp_replace(coalesce(p_text, ''), E'\r\n|\r', E'\n', 'g')
                )
            ),
            '\s+',
            ' ',
            'g'
        ),
        ''
    );
$$;


--
-- Name: inv22_date_text(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inv22_date_text(p_date date) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN p_date IS NULL THEN NULL
        ELSE
            extract(month from p_date)::int::text || '/' ||
            extract(day from p_date)::int::text || '/' ||
            extract(year from p_date)::int::text
    END;
$$;


--
-- Name: is_admin_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin_role() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('ADMIN');
$$;


--
-- Name: is_app_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_app_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('ADMIN');
$$;


--
-- Name: is_authenticated_app_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_authenticated_app_user() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.current_app_user_id() IS NOT NULL;
$$;


--
-- Name: is_chief(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_chief() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('CHIEF');
$$;


--
-- Name: is_developer(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_developer() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('DEVELOPER');
$$;


--
-- Name: is_prosecutor_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_prosecutor_role() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('PROSECUTOR');
$$;


--
-- Name: is_staff_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_staff_role() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.has_app_role('STAFF');
$$;


--
-- Name: legacy_age_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_age_number(p_text text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
BEGIN
    v := public.legacy_clean_age_value(p_text);
    IF v ~ '^\d{1,3}$' THEN
        RETURN v::integer;
    END IF;
    RETURN NULL;
END;
$_$;


--
-- Name: legacy_alias_from_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_alias_from_name(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
    a text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    IF v ~ '@' THEN
        a := regexp_replace(v, '^.*@\s*', '');
    ELSIF v ~* 'a\.?\s*k\.?\s*a\.?' THEN
        a := regexp_replace(v, '^.*a\.?\s*k\.?\s*a\.?\s*', '', 'i');
    ELSIF v ~* '\m(aka|alias|alyas)\M' THEN
        a := regexp_replace(v, '^.*\m(aka|alias|alyas)\M\s*', '', 'i');
    ELSE
        RETURN NULL;
    END IF;

    a := regexp_replace(a, '\s*\(\s*(MINOR|SENIOR|PWD|AT\s*LARGE|AT-LARGE|ATLARGE)\s*\)\s*', ' ', 'gi');
    a := regexp_replace(a, '\s+', ' ', 'g');
    a := btrim(a);
    RETURN NULLIF(left(a, 255), '');
END;
$$;


--
-- Name: legacy_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_bool(p_text text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := upper(btrim(COALESCE(p_text, '')));
    IF v = '' THEN
        RETURN NULL;
    ELSIF v IN ('YES', 'Y', 'TRUE', '1') THEN
        RETURN true;
    ELSIF v IN ('NO', 'N', 'FALSE', '0') THEN
        RETURN false;
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: legacy_canonical_violation(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_canonical_violation(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := upper(public.legacy_clean_text(p_text));
    IF v IS NULL THEN
        RETURN NULL;
    END IF;
    v := regexp_replace(v, '[[:punct:]]+', ' ', 'g');
    v := regexp_replace(v, '\s+', ' ', 'g');
    v := btrim(v);
    v := replace(v, 'VIOLATION OF ', 'VIOL OF ');
    v := replace(v, 'VIOL. OF ', 'VIOL OF ');
    v := replace(v, 'PHYSICAL INJURIES', 'PHYSICAL INJURY');
    v := replace(v, 'GRAVE THREATS', 'GRAVE THREAT');
    RETURN NULLIF(v, '');
END;
$$;


--
-- Name: legacy_clean_age_value(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_clean_age_value(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    u text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;
    v := regexp_replace(v, '^\s*\d+\s*[\.\)]\s*', '', 'g');
    v := btrim(v);
    u := upper(regexp_replace(v, '\s+', ' ', 'g'));
    IF u IN ('LEGAL AGE', 'OF LEGAL AGE', 'ALL LEGAL AGE', 'BOTH LEGAL AGE', 'BOTH OF LEGAL AGE', 'ALL OF LEGAL AGE', 'ALL ARE LEGAL AGE') THEN
        RETURN 'LEGAL AGE';
    END IF;
    IF u IN ('MINOR', 'MINORS') THEN
        RETURN 'MINOR';
    END IF;
    IF u ~ '^\d{1,3}$' THEN
        RETURN u;
    END IF;
    RETURN NULL;
END;
$_$;


--
-- Name: legacy_clean_gender_value(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_clean_gender_value(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
    u text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;
    v := regexp_replace(v, '^\s*\d+\s*[\.\)]\s*', '', 'g');
    u := upper(btrim(v));
    IF u IN ('MALE', 'M') THEN
        RETURN 'MALE';
    END IF;
    IF u IN ('FEMALE', 'F') THEN
        RETURN 'FEMALE';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: legacy_clean_person_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_clean_person_name(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    -- Remove common enumerators: 1. NAME, 2) NAME, 3-NAME.
    v := regexp_replace(v, '^\s*\d+\s*[\.\)\-]\s*', '', 'g');

    -- Keep the organization/person before representative text. The complete raw
    -- representative text is preserved in raw_json and migration_review_items.
    -- The comparison/export view can use raw fallback for REP BY rows.
    IF v ~* '\mREP\.?\s+BY\M|REPRESENTED BY' THEN
        v := regexp_replace(v, '\s*(REP\.?\s+BY|REPRESENTED BY)\s*:?.*$', '', 'i');
    END IF;

    -- Alias handling. If the whole entry starts with @, the alias is the available name.
    IF v ~ '^\s*@' THEN
        v := regexp_replace(v, '^\s*@\s*', '', 'g');
    ELSE
        v := regexp_replace(v, '\s+(A\.?\s*K\.?\s*A\.?|AKA|ALIAS|ALYAS)\s+.*$', '', 'gi');
        v := regexp_replace(v, '\s*@.*$', '', 'g');
    END IF;

    -- Remove descriptor tags from the display name; descriptors are stored separately.
    v := regexp_replace(v, '\s*\(\s*(MINOR|SENIOR|PWD|AT\s*LARGE|AT-LARGE|ATLARGE|DECEASED)\s*\)\s*', ' ', 'gi');
    v := regexp_replace(v, '\s*[-,]?\s*(MINOR|SENIOR|PWD|AT\s*LARGE|AT-LARGE|ATLARGE|DECEASED)\s*$', '', 'gi');

    -- Remove common ranks/titles from the searchable name but preserve them in descriptor.
    v := regexp_replace(v, '^\s*(PSSG|PCPL|PAT|PMSG|PMSg|PEMS|PSMS|PLT|PMAJ|PCPT|P/CPL|CPL|SPO[0-9]?|PO[0-9]?|ATTY\.?|DR\.?|DRA\.?)\s+', '', 'i');

    v := regexp_replace(v, '\s*,\s*', ', ', 'g');
    v := regexp_replace(v, '\s+', ' ', 'g');
    v := btrim(v, ' ,.;:-');

    v := public.legacy_format_person_name(v);

    IF public.legacy_is_placeholder_person(v) THEN
        RETURN NULL;
    END IF;

    RETURN NULLIF(left(v, 255), '');
END;
$_$;


--
-- Name: legacy_clean_text(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_clean_text(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := btrim(COALESCE(p_text, ''));
    IF v = '' THEN
        RETURN NULL;
    END IF;
    v := replace(v, E'\r', E'\n');
    v := regexp_replace(v, E'[ \t]+', ' ', 'g');
    v := regexp_replace(v, E'\n+', E'\n', 'g');
    v := btrim(v);
    RETURN NULLIF(v, '');
END;
$$;


--
-- Name: legacy_clean_violation_text(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_clean_violation_text(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_text TEXT;
BEGIN
    IF p_text IS NULL OR btrim(p_text) = '' THEN
        RETURN NULL;
    END IF;

    -- Normalize Windows/Mac line breaks to \n
    v_text := replace(p_text, E'\r\n', E'\n');
    v_text := replace(v_text, E'\r', E'\n');

    -- Clean spaces around each line
    v_text := regexp_replace(v_text, '[ \t]+', ' ', 'g');
    v_text := regexp_replace(v_text, '[ \t]*\n[ \t]*', E'\n', 'g');

    -- Convert one or more line breaks into comma separator
    v_text := regexp_replace(v_text, E'\n+', ', ', 'g');

    -- Clean extra spaces around commas
    v_text := regexp_replace(v_text, '\s*,\s*', ', ', 'g');

    -- Remove duplicate commas if any
    v_text := regexp_replace(v_text, '(,\s*)+', ', ', 'g');

    RETURN NULLIF(btrim(v_text, ' ,'), '');
END;
$$;


--
-- Name: legacy_docket_annotation(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_docket_annotation(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
    n text;
    ann text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    n := public.legacy_extract_leading_int(v)::text;
    ann := btrim(regexp_replace(v, '^\s*0*[0-9]+\s*', '', ''));
    IF ann IS NULL OR ann = '' THEN
        RETURN NULL;
    END IF;

    RETURN ann;
END;
$$;


--
-- Name: legacy_extract_after_leading_int(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_extract_after_leading_int(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_text IS NULL THEN NULL
    ELSE legacy_clean_text(
      regexp_replace(
        trim(p_text),
        '^\s*\d+\s*[-–—:;,.]*\s*',
        '',
        ''
      )
    )
  END;
$$;


--
-- Name: legacy_extract_int(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_extract_int(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_text IS NULL THEN NULL
    WHEN regexp_replace(p_text, '[^0-9]', '', 'g') = '' THEN NULL
    ELSE regexp_replace(p_text, '[^0-9]', '', 'g')::INT
  END;
$$;


--
-- Name: legacy_extract_leading_int(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_extract_leading_int(p_text text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
BEGIN
    v := btrim(COALESCE(p_text, ''));
    IF v = '' THEN
        RETURN NULL;
    END IF;
    IF v ~ '^\s*0*([0-9]+)' THEN
        RETURN regexp_replace(v, '^\s*0*([0-9]+).*$', '\1')::integer;
    END IF;
    RETURN NULL;
END;
$_$;


--
-- Name: legacy_format_natural_person_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_format_natural_person_name(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    tokens text[];
    n int;
    last_name text;
    first_name text;
    middle_name text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN RETURN NULL; END IF;
    v := regexp_replace(v, '\s+', ' ', 'g');
    v := btrim(v, ' ,.;:-');

    IF position(',' in v) > 0 THEN
        RETURN public.legacy_format_person_name(v);
    END IF;

    tokens := regexp_split_to_array(v, '\s+');
    n := array_length(tokens, 1);
    IF n IS NULL OR n = 0 THEN RETURN NULL; END IF;
    IF n = 1 THEN RETURN v; END IF;

    last_name := tokens[n];
    IF n >= 3 AND tokens[n - 1] ~ '^[A-ZÑ]\.?$' THEN
        middle_name := replace(tokens[n - 1], '.', '');
        first_name := array_to_string(tokens[1:greatest(n - 2, 1)], ' ');
    ELSE
        middle_name := NULL;
        first_name := array_to_string(tokens[1:n - 1], ' ');
    END IF;

    IF middle_name IS NULL OR middle_name = '' THEN
        RETURN last_name || ', ' || first_name;
    END IF;
    RETURN last_name || ', ' || first_name || ' y ' || middle_name;
END;
$_$;


--
-- Name: legacy_format_person_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_format_person_name(p_full_name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    last_part text;
    last_base text;
    suffix_raw text;
    suffix_norm text;
    last_out text;
    after_comma text;
    first_part text;
    middle_part text;
BEGIN
    v := public.legacy_clean_text(p_full_name);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*,\s*', ', ', 'g');
    v := regexp_replace(v, '\s+', ' ', 'g');
    v := btrim(v, ' ,.;:-');

    -- Only comma-form names are standardized here:
    -- LAST [SUFFIX], FIRST [y MIDDLE] or LAST, FIRST MIDDLE_INITIAL
    IF position(',' in v) = 0 THEN
        RETURN left(v, 255);
    END IF;

    last_part := btrim(split_part(v, ',', 1));
    after_comma := btrim(substr(v, position(',' in v) + 1));

    IF last_part ~* '\s+(JR\.?|SR\.?|II|III|IV|V)$' THEN
        suffix_raw := regexp_replace(last_part, '^.*\s+(JR\.?|SR\.?|II|III|IV|V)$', '\1', 'i');
        suffix_norm := upper(replace(suffix_raw, '.', ''));
        last_base := btrim(regexp_replace(last_part, '\s+(JR\.?|SR\.?|II|III|IV|V)$', '', 'i'));
    ELSE
        suffix_norm := NULL;
        last_base := last_part;
    END IF;

    last_base := regexp_replace(last_base, '\s+', ' ', 'g');

    IF suffix_norm IS NULL THEN
        last_out := last_base;
    ELSIF suffix_norm IN ('JR', 'SR') THEN
        last_out := last_base || ' ' || suffix_norm || '.';
    ELSE
        last_out := last_base || ' ' || suffix_norm;
    END IF;

    after_comma := regexp_replace(after_comma, '\s+', ' ', 'g');
    after_comma := btrim(after_comma, ' ,.;:-');

    IF after_comma IS NULL OR after_comma = '' THEN
        RETURN left(last_out, 255);
    END IF;

    -- Existing legacy middle-name indicator can be capital Y or small y.
    -- Standardize the full_name separator to small "y".
    IF after_comma ~* '\s+y\s+' THEN
        first_part := btrim(regexp_replace(after_comma, '^(.*?)\s+[Yy]\s+.*$', '\1'));
        middle_part := btrim(regexp_replace(after_comma, '^.*?\s+[Yy]\s+', '', 'i'));
    -- If no y separator exists but the final token is a single-letter middle initial,
    -- move it to middle_name/full_name middle segment.
    ELSIF after_comma ~ '\s+[A-ZÑ]\.?$' THEN
        first_part := btrim(regexp_replace(after_comma, '\s+([A-ZÑ])\.?$', ''));
        middle_part := btrim(regexp_replace(after_comma, '^.*\s+([A-ZÑ])\.?$', '\1'));
    ELSE
        first_part := after_comma;
        middle_part := NULL;
    END IF;

    IF middle_part IS NULL OR middle_part = '' THEN
        RETURN left(last_out || ', ' || first_part, 255);
    END IF;

    middle_part := regexp_replace(middle_part, '\s+', ' ', 'g');
    RETURN left(last_out || ', ' || first_part || ' y ' || middle_part, 255);
END;
$_$;


--
-- Name: legacy_gender_normalized(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_gender_normalized(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := upper(COALESCE(public.legacy_clean_text(p_text), ''));
    IF v IN ('M', 'MALE') THEN RETURN 'MALE'; END IF;
    IF v IN ('F', 'FEMALE') THEN RETURN 'FEMALE'; END IF;
    IF v = '' THEN RETURN NULL; END IF;
    RETURN 'UNKNOWN';
END;
$$;


--
-- Name: legacy_has_rep_by(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_has_rep_by(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT COALESCE(public.legacy_clean_text($1), '') ~* '(REP\.?\s*BY|REPRESENTED\s+BY)';
$_$;


--
-- Name: legacy_is_organization_text(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_is_organization_text(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT COALESCE(public.legacy_clean_text($1), '') ~* '(^|\m)(CORP\.?|CORPORATION|INC\.?|INCORPORATED|COMPANY|CO\.?|BANK|LENDING|FINANCE|CITY GOVERNMENT|MUNICIPALITY|BARANGAY|BRGY\.?|OFFICE|AGENCY|BUREAU|DEPARTMENT|SCHOOL|UNIVERSITY|COLLEGE|HOSPITAL|FOUNDATION|ASSOCIATION|COOPERATIVE|COOP)(\M|$)';
$_$;


--
-- Name: legacy_is_placeholder_person(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_is_placeholder_person(p_text text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := upper(btrim(COALESCE(p_text, '')));
    v := regexp_replace(v, '[\s\.-]+', ' ', 'g');
    v := btrim(v);
    RETURN v IS NULL
        OR v = ''
        OR v IN ('N A', 'NA', 'NONE', 'UNKNOWN', 'UNK', 'NO NAME', 'JOHN DOE', 'JANE DOE', 'NIL');
END;
$$;


--
-- Name: legacy_line(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_line(p_label text, p_value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN legacy_clean_text(p_value) IS NULL THEN NULL
    WHEN upper(legacy_clean_text(p_value)) = 'SUMMARY' THEN NULL
    ELSE p_label || ': ' || legacy_clean_text(p_value)
  END;
$$;


--
-- Name: legacy_main_party_from_repby(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_main_party_from_repby(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN RETURN NULL; END IF;
    IF public.legacy_has_rep_by(v) THEN
        v := regexp_replace(v, '\s*(REP\.?\s*BY|REPRESENTED\s+BY)\s*:?.*$', '', 'i');
    END IF;
    RETURN NULLIF(btrim(v, ' ,.;:-'), '');
END;
$_$;


--
-- Name: legacy_norm_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_norm_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT NULLIF(
    regexp_replace(
      upper(legacy_clean_text(p_text)),
      '[^A-Z0-9]+', '_', 'g'
    ),
    ''
  );
$$;


--
-- Name: legacy_norm_court_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_norm_court_code(raw_value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN raw_value IS NULL OR trim(raw_value) = '' THEN NULL
    ELSE upper(regexp_replace(trim(raw_value), '\s+', ' ', 'g'))
  END;
$$;


--
-- Name: legacy_org_type(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_org_type(p_text text, p_descriptor text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := upper(COALESCE(p_descriptor, '') || ' ' || COALESCE(p_text, ''));
    IF v ~ 'CITY GOVERNMENT' THEN RETURN 'CITY_GOVERNMENT'; END IF;
    IF v ~ 'BARANGAY|BRGY' THEN RETURN 'BARANGAY'; END IF;
    IF v ~ 'BANK' THEN RETURN 'BANK'; END IF;
    IF v ~ 'LENDING' THEN RETURN 'LENDING_COMPANY'; END IF;
    IF v ~ 'AGENCY|BUREAU|DEPARTMENT|OFFICE|GOVERNMENT' THEN RETURN 'GOVERNMENT_OFFICE'; END IF;
    IF v ~ 'SCHOOL|UNIVERSITY|COLLEGE' THEN RETURN 'SCHOOL'; END IF;
    IF v ~ 'CORP|CORPORATION|INC|INCORPORATED|COMPANY|FINANCE' THEN RETURN 'CORPORATION'; END IF;
    RETURN 'ORGANIZATION';
END;
$$;


--
-- Name: legacy_parse_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_parse_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    m int;
    d int;
    y int;
BEGIN
    v := btrim(COALESCE(p_text, ''));
    IF v = '' THEN
        RETURN NULL;
    END IF;

    -- Reject values that clearly contain multiple dates/notes.
    IF v ~ E'[\n\r;]' OR v ~* '( and |/.*?/|,.*[0-9])' THEN
        -- Allow simple numeric slash dates only.
        IF NOT (v ~ '^\d{1,2}/\d{1,2}/\d{2,5}$') THEN
            RETURN NULL;
        END IF;
    END IF;

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        BEGIN
            RETURN v::date;
        EXCEPTION WHEN OTHERS THEN
            RETURN NULL;
        END;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,5}$' THEN
        parts := string_to_array(v, '/');
        m := parts[1]::int;
        d := parts[2]::int;
        y := parts[3]::int;

        IF y < 100 THEN
            y := 2000 + y;
        ELSIF y > 9999 AND length(parts[3]) = 5 AND right(parts[3], 1) = '2' THEN
            -- Handles obvious typo like 20222 -> 2022 conservatively.
            y := left(parts[3], 4)::int;
        END IF;

        BEGIN
            RETURN make_date(y, m, d);
        EXCEPTION WHEN OTHERS THEN
            RETURN NULL;
        END;
    END IF;

    RETURN NULL;
END;
$_$;


--
-- Name: legacy_parse_date_safe(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_parse_date_safe(raw_value text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
  v TEXT;
  n NUMERIC;
BEGIN
  v := NULLIF(trim(raw_value), '');
  IF v IS NULL THEN
    RETURN NULL;
  END IF;

  -- Excel serial date. Excel date system starts 1899-12-30 in common import practice.
  IF v ~ '^\d+(\.\d+)?$' THEN
    n := v::NUMERIC;
    IF n > 20000 AND n < 60000 THEN
      RETURN DATE '1899-12-30' + n::INT;
    END IF;
  END IF;

  BEGIN
    RETURN v::DATE;
  EXCEPTION WHEN others THEN
    RETURN NULL;
  END;
END;
$_$;


--
-- Name: legacy_part_value(text, integer, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_part_value(p_text text, p_seq integer, p_total bigint, p_kind text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
    arr text[];
    normalized text;
    candidate text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;
    normalized := upper(regexp_replace(v, '\s+', ' ', 'g'));
    IF p_kind = 'AGE' THEN
        IF normalized IN ('LEGAL AGE', 'OF LEGAL AGE') THEN
            RETURN 'LEGAL AGE';
        END IF;
        IF normalized IN ('ALL LEGAL AGE', 'BOTH LEGAL AGE', 'BOTH OF LEGAL AGE', 'ALL OF LEGAL AGE', 'ALL ARE LEGAL AGE') THEN
            RETURN 'LEGAL AGE';
        END IF;
    END IF;
    arr := regexp_split_to_array(
        regexp_replace(v, '[[:space:]]+([0-9]+)[[:space:]]*[\.\)][[:space:]]+', E'\n\\1. ', 'g'),
        E'\n+|;'
    );
    IF array_length(arr, 1) >= p_seq THEN
        candidate := NULLIF(btrim(arr[p_seq]), '');
    ELSIF p_total = 1 THEN
        candidate := v;
    ELSE
        candidate := NULL;
    END IF;
    IF candidate IS NULL THEN
        RETURN NULL;
    END IF;
    IF p_kind = 'AGE' THEN
        RETURN public.legacy_clean_age_value(candidate);
    ELSIF p_kind = 'GENDER' THEN
        RETURN public.legacy_clean_gender_value(candidate);
    END IF;
    RETURN candidate;
END;
$$;


--
-- Name: legacy_person_descriptor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_person_descriptor(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    d text := NULL;
    r text;
BEGIN
    v := upper(btrim(COALESCE(p_text, '')));

    IF v = '' THEN
        RETURN NULL;
    END IF;

    IF v ~ '^\s*(PSSG|PCPL|PAT|PMSG|PMSg|PEMS|PSMS|PLT|PMAJ|PCPT|P/CPL|CPL|SPO[0-9]?|PO[0-9]?|ATTY\.?|DR\.?|DRA\.?)\s+' THEN
        r := regexp_replace(v, '^\s*(PSSG|PCPL|PAT|PMSG|PMSG|PEMS|PSMS|PLT|PMAJ|PCPT|P/CPL|CPL|SPO[0-9]?|PO[0-9]?|ATTY\.?|DR\.?|DRA\.?)\s+.*$', '\1', 'i');
        d := upper(r);
    ELSIF v LIKE '%CORPORATION%' OR v LIKE '% CORP%' OR v LIKE '% INC%' OR v LIKE '%COMPANY%' OR v LIKE '%MARTS INC%' THEN
        d := 'COMPANY';
    ELSIF v LIKE '%CITY GOVERNMENT%' OR v LIKE '%BARANGAY%' OR v LIKE '%MUNICIPAL%' OR v LIKE '%PROVINCE%' THEN
        d := 'GOVERNMENT OFFICE';
    ELSIF v IN ('PNP', 'BFP', 'BJMP') OR v LIKE '%POLICE%' OR v LIKE '%BUREAU%' OR v LIKE '%OFFICE%' THEN
        d := 'AGENCY/OFFICE';
    END IF;

    IF v ~* '\mREP\.?\s+BY\M|REPRESENTED BY' THEN
        d := concat_ws('; ', d, 'REPRESENTED');
    END IF;

    IF v LIKE '%DECEASED%' THEN
        d := concat_ws('; ', d, 'DECEASED');
    END IF;

    RETURN NULLIF(d, '');
END;
$_$;


--
-- Name: legacy_person_first_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_person_first_name(p_full_name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    after_comma text;
BEGIN
    v := public.legacy_format_person_name(p_full_name);
    IF v IS NULL OR position(',' in v) = 0 THEN RETURN NULL; END IF;
    after_comma := btrim(substr(v, position(',' in v) + 1));
    after_comma := regexp_replace(after_comma, '\s+', ' ', 'g');

    IF after_comma ~* '\s+y\s+' THEN
        after_comma := regexp_replace(after_comma, '\s+[Yy]\s+.*$', '', 'g');
    ELSIF after_comma ~ '\s+[A-ZÑ]\.?$' THEN
        after_comma := regexp_replace(after_comma, '\s+([A-ZÑ])\.?$', '', 'g');
    END IF;

    RETURN NULLIF(left(btrim(after_comma), 150), '');
END;
$_$;


--
-- Name: legacy_person_last_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_person_last_name(p_full_name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    last_part text;
BEGIN
    v := public.legacy_format_person_name(p_full_name);
    IF v IS NULL OR position(',' in v) = 0 THEN RETURN NULL; END IF;
    last_part := btrim(split_part(v, ',', 1));
    last_part := regexp_replace(last_part, '\s+(JR\.?|SR\.?|II|III|IV|V)$', '', 'i');
    last_part := regexp_replace(last_part, '\s+', ' ', 'g');
    RETURN NULLIF(left(btrim(last_part), 150), '');
END;
$_$;


--
-- Name: legacy_person_middle_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_person_middle_name(p_full_name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    after_comma text;
    mid text;
BEGIN
    v := public.legacy_format_person_name(p_full_name);
    IF v IS NULL OR position(',' in v) = 0 THEN RETURN NULL; END IF;
    after_comma := btrim(substr(v, position(',' in v) + 1));
    after_comma := regexp_replace(after_comma, '\s+', ' ', 'g');

    IF after_comma ~* '\s+y\s+' THEN
        mid := regexp_replace(after_comma, '^.*?\s+[Yy]\s+', '', 'i');
    ELSIF after_comma ~ '\s+[A-ZÑ]\.?$' THEN
        mid := regexp_replace(after_comma, '^.*\s+([A-ZÑ])\.?$', '\1');
    ELSE
        RETURN NULL;
    END IF;

    mid := regexp_replace(mid, '\s+', ' ', 'g');
    RETURN NULLIF(left(btrim(mid), 150), '');
END;
$_$;


--
-- Name: legacy_person_suffix(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_person_suffix(p_full_name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    last_part text;
    sx text;
BEGIN
    v := public.legacy_format_person_name(p_full_name);
    IF v IS NULL THEN RETURN NULL; END IF;
    last_part := btrim(split_part(v, ',', 1));
    IF last_part ~* '\s+(JR\.?|SR\.?|II|III|IV|V)$' THEN
        sx := regexp_replace(last_part, '^.*\s+(JR\.?|SR\.?|II|III|IV|V)$', '\1', 'i');
        RETURN upper(replace(sx, '.', ''));
    END IF;
    RETURN NULL;
END;
$_$;


--
-- Name: legacy_primary_name_from_alias(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_primary_name_from_alias(p_name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v TEXT;
BEGIN
    v := NULLIF(btrim(COALESCE(p_name, '')), '');
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    IF v ~ '@' THEN
        v := regexp_replace(v, '\s*@.*$', '');
    ELSIF v ~* 'a\.?\s*k\.?\s*a\.?' THEN
        v := regexp_replace(v, '\s+a\.?\s*k\.?\s*a\.?\s+.*$', '', 'i');
    ELSIF v ~* '\m(aka|alias|alyas)\M' THEN
        v := regexp_replace(v, '\s+\m(aka|alias|alyas)\M\s+.*$', '', 'i');
    END IF;

    RETURN NULLIF(btrim(v), '');
END;
$_$;


--
-- Name: legacy_prosecutor_short(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_prosecutor_short(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := upper(regexp_replace(btrim(COALESCE(p_text, '')), '\s+', ' ', 'g'));

    IF v = '' THEN
        RETURN NULL;
    END IF;

    IF v IN ('PARRA', 'ASPP PARRA', 'APP PARRA') THEN
        RETURN 'APP PARRA';
    END IF;

    IF v IN ('ASCP TAMONDONG', 'ACP TAMONDONG') THEN
        RETURN 'ACP TAMONDONG';
    END IF;

    RETURN v;
END;
$$;


--
-- Name: legacy_representative_from_repby(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_representative_from_repby(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := public.legacy_clean_text(p_text);
    IF v IS NULL OR NOT public.legacy_has_rep_by(v) THEN RETURN NULL; END IF;
    v := regexp_replace(v, '^.*?(REP\.?\s*BY|REPRESENTED\s+BY)\s*:?', '', 'i');
    v := regexp_replace(v, E'\n+', ' ', 'g');
    v := regexp_replace(v, '\s+', ' ', 'g');
    RETURN NULLIF(btrim(v, ' ,.;:-'), '');
END;
$$;


--
-- Name: legacy_split_courts(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_split_courts(p_court_raw text, p_charge_raw text) RETURNS TABLE(court_order integer, court_code text, charge_filed text, review_reason text)
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    p_rtc int;
    p_mtc int;
    charge1 text;
    charge2 text;
BEGIN
    v := upper(public.legacy_clean_text(p_court_raw));

    IF v IS NULL THEN
        RETURN;
    END IF;

    v := replace(v, 'MTC ', 'MTCC ');
    v := replace(v, 'MTC-', 'MTCC-');

    p_rtc := NULLIF(position('RTC' in v), 0);
    p_mtc := NULLIF(position('MTCC' in v), 0);

    IF p_rtc IS NOT NULL AND p_mtc IS NULL THEN
        court_order := 1;
        court_code := 'RTC';
        charge_filed := NULLIF(public.legacy_clean_text(p_charge_raw), '');
        review_reason := 'Legacy Excel court value requires manual verification';
        RETURN NEXT;
        RETURN;
    END IF;

    IF p_mtc IS NOT NULL AND p_rtc IS NULL THEN
        court_order := 1;
        court_code := 'MTCC';
        charge_filed := NULLIF(public.legacy_clean_text(p_charge_raw), '');
        review_reason := 'Legacy Excel court value requires manual verification';
        RETURN NEXT;
        RETURN;
    END IF;

    IF p_rtc IS NOT NULL AND p_mtc IS NOT NULL THEN
        IF p_rtc < p_mtc THEN
            charge1 := btrim(regexp_replace(substr(v, 1, p_rtc - 1), '[-/\s]+$', '', 'g'));
            charge2 := btrim(regexp_replace(substr(v, p_rtc + 3, p_mtc - (p_rtc + 3)), '^[-/\s]+|[-/\s]+$', '', 'g'));

            court_order := 1;
            court_code := 'RTC';
            charge_filed := NULLIF(charge1, '');
            review_reason := 'Mixed court value from legacy Excel; needs manual review';
            RETURN NEXT;

            court_order := 2;
            court_code := 'MTCC';
            charge_filed := NULLIF(charge2, '');
            review_reason := 'Mixed court value from legacy Excel; needs manual review';
            RETURN NEXT;
        ELSE
            charge1 := btrim(regexp_replace(substr(v, p_mtc + 4, p_rtc - (p_mtc + 4)), '^[-/\s]+|[-/\s]+$', '', 'g'));
            charge2 := btrim(regexp_replace(substr(v, p_rtc + 3), '^[-/\s]+|[-/\s]+$', '', 'g'));

            court_order := 1;
            court_code := 'MTCC';
            charge_filed := NULLIF(charge1, '');
            review_reason := 'Mixed court value from legacy Excel; needs manual review';
            RETURN NEXT;

            court_order := 2;
            court_code := 'RTC';
            charge_filed := NULLIF(charge2, '');
            review_reason := 'Mixed court value from legacy Excel; needs manual review';
            RETURN NEXT;
        END IF;
        RETURN;
    END IF;

    -- Unknown court text: preserve as review item using no court_id later.
    court_order := 1;
    court_code := NULL;
    charge_filed := NULLIF(public.legacy_clean_text(p_charge_raw), '');
    review_reason := 'Unrecognized court value from legacy Excel; needs manual review';
    RETURN NEXT;
END;
$_$;


--
-- Name: legacy_split_people(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_split_people(p_text text, p_default_role text) RETURNS TABLE(seq integer, raw_name text, clean_name text, alias_name text, descriptor text)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    arr text[];
    work text;
    line text;
    n int := 0;
    cleaned text;
BEGIN
    IF public.legacy_clean_text(p_text) IS NULL THEN
        RETURN;
    END IF;

    work := replace(COALESCE(p_text, ''), E'\r', E'\n');

    -- Normalize inline enumerators to line breaks. Handles "1. NAME 2.NAME" and "1) NAME 2) NAME".
    work := regexp_replace(work, '(^|[[:space:]])([0-9]+)[[:space:]]*[\.)][[:space:]]*', E'\n\\2. ', 'g');

    arr := regexp_split_to_array(work, E'\n+');

    FOREACH line IN ARRAY arr LOOP
        line := public.legacy_clean_text(line);
        IF line IS NULL THEN
            CONTINUE;
        END IF;

        cleaned := public.legacy_clean_person_name(line);
        IF cleaned IS NULL OR public.legacy_is_placeholder_person(cleaned) THEN
            CONTINUE;
        END IF;

        n := n + 1;
        seq := n;
        raw_name := line;
        clean_name := cleaned;
        alias_name := public.legacy_alias_from_name(line);
        descriptor := public.legacy_person_descriptor(line);
        RETURN NEXT;
    END LOOP;
END;
$$;


--
-- Name: legacy_split_repby_representatives(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_split_repby_representatives(p_text text) RETURNS TABLE(seq integer, raw_representative text, is_probable_person boolean, review_reason text)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    block text;
    work text;
    line text;
    cleaned text;
    n int := 0;
BEGIN
    block := public.legacy_representative_from_repby(p_text);
    IF block IS NULL THEN RETURN; END IF;

    work := replace(block, E'\r', E'\n');
    work := regexp_replace(work, '(^|[[:space:]])([0-9]+)[[:space:]]*[\.)][[:space:]]*', E'\n\\2. ', 'g');
    work := regexp_replace(work, E'\n+', E'\n', 'g');

    FOR line IN SELECT * FROM regexp_split_to_table(work, E'\n+') LOOP
        cleaned := public.legacy_clean_text(line);
        IF cleaned IS NULL THEN CONTINUE; END IF;
        cleaned := regexp_replace(cleaned, '^\s*[0-9]+\s*[\.)]\s*', '', 'g');
        cleaned := regexp_replace(cleaned, '\s+', ' ', 'g');
        cleaned := btrim(cleaned, ' ,.;:-');
        IF cleaned IS NULL OR cleaned = '' THEN CONTINUE; END IF;

        n := n + 1;
        seq := n;
        raw_representative := cleaned;

        IF cleaned ~* '(DIRECTORS?|OFFICERS?|STOCKHOLDERS?|OWNERS?|EMPLOYEES?|MEMBERS?)\s+(AND|/|OR)?\s*(DIRECTORS?|OFFICERS?|STOCKHOLDERS?|OWNERS?|EMPLOYEES?|MEMBERS?)?\s*(OF|FOR)'
           OR public.legacy_is_organization_text(cleaned) THEN
            is_probable_person := false;
            review_reason := 'NON_PERSON_OR_COLLECTIVE_REPRESENTATIVE_TEXT';
        ELSE
            is_probable_person := true;
            review_reason := NULL;
        END IF;
        RETURN NEXT;
    END LOOP;
END;
$$;


--
-- Name: legacy_split_violations(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_split_violations(p_text text) RETURNS TABLE(seq integer, raw_violation text, norm_title text)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    arr text[];
    work text;
    line text;
    n int := 0;
    cleaned text;
BEGIN
    IF public.legacy_clean_text(p_text) IS NULL THEN
        RETURN;
    END IF;

    work := replace(COALESCE(p_text, ''), E'\r', E'\n');

    -- V8: split violations by line breaks and explicit enumerators only.
    -- Do NOT split on semicolon because some legacy rows use semicolon inside one broken phrase,
    -- e.g. "RIR TO SERIOUS PHYSICAL; INJURY AND DAMAGE TO PROPERTY".
    work := regexp_replace(work, '(^|[[:space:]])([0-9]+)[[:space:]]*[\.)][[:space:]]*', E'\n\\2. ', 'g');
    arr := regexp_split_to_array(work, E'\n+');

    FOREACH line IN ARRAY arr LOOP
        cleaned := public.legacy_clean_text(line);
        IF cleaned IS NULL THEN
            CONTINUE;
        END IF;

        cleaned := regexp_replace(cleaned, '^\s*\d+\s*[\.]\)\s*', '', 'g');
        cleaned := regexp_replace(cleaned, '^\s*\d+\s*[\.)]\s*', '', 'g');
        cleaned := regexp_replace(cleaned, '\s+', ' ', 'g');
        cleaned := btrim(cleaned);

        IF cleaned IS NULL OR cleaned = '' THEN
            CONTINUE;
        END IF;

        n := n + 1;
        seq := n;
        raw_violation := cleaned;
        norm_title := public.legacy_canonical_violation(cleaned);
        RETURN NEXT;
    END LOOP;
END;
$$;


--
-- Name: legacy_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_status_code(p_text text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
    has_filed boolean;
    has_dismiss boolean;
BEGIN
    v := upper(btrim(COALESCE(p_text, '')));

    IF v = '' THEN
        RETURN 'NEED_USER_REVIEW';
    END IF;

    v := replace(v, 'DISMISSSED', 'DISMISSED');

    has_filed := v LIKE '%FILED%';
    has_dismiss := v LIKE '%DISMISS%';

    IF has_filed AND has_dismiss THEN
        RETURN 'MIXED_RESULT';
    END IF;

    IF v LIKE '%INDORSED%OPP%CAVITE%' OR v LIKE '%ENDORSED%OPP%CAVITE%' THEN
        RETURN 'INDORSED';
    END IF;

    IF v LIKE '%DIVERSION%TERMINATED%' OR v LIKE '%DIVERSION PROCEEDING / TERMINATED%' THEN
        RETURN 'DIVERSION_TERMINATED';
    END IF;

    IF v LIKE '%DIVERSION PROCEEDING%' THEN
        RETURN 'DIVERSION_PROCEEDING';
    END IF;

    IF v LIKE '%CICL%' THEN
        RETURN 'CICL';
    END IF;

    IF has_filed THEN
        RETURN 'FILED';
    END IF;

    IF has_dismiss THEN
        RETURN 'DISMISSED';
    END IF;

    RETURN 'NEED_USER_REVIEW';
END;
$$;


--
-- Name: legacy_value_for_index(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_value_for_index(p_text text, p_index integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  v_clean TEXT;
  v_lines TEXT[];
  v_line TEXT;
  v_values TEXT[] := ARRAY[]::TEXT[];
BEGIN
  v_clean := legacy_clean_text(p_text);
  IF v_clean IS NULL THEN
    RETURN NULL;
  END IF;

  v_lines := regexp_split_to_array(replace(v_clean, E'\r', ''), E'\n+');

  FOREACH v_line IN ARRAY v_lines LOOP
    v_line := legacy_clean_text(regexp_replace(v_line, '^\s*\d+\s*[\.)-]\s*', '', 'g'));
    IF v_line IS NOT NULL THEN
      v_values := array_append(v_values, v_line);
    END IF;
  END LOOP;

  IF array_length(v_values, 1) IS NULL THEN
    RETURN NULL;
  END IF;

  -- If there is only one value, apply it to every person in that side.
  -- Example: ALL LEGAL AGE, NO, MALE, FEMALE.
  IF array_length(v_values, 1) = 1 THEN
    RETURN v_values[1];
  END IF;

  IF p_index <= array_length(v_values, 1) THEN
    RETURN v_values[p_index];
  END IF;

  RETURN NULL;
END;
$$;


--
-- Name: legacy_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_year(p_text text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
BEGIN
    v := btrim(COALESCE(p_text, ''));
    IF v ~ '^\d{2}$' THEN
        RETURN 2000 + v::integer;
    ELSIF v ~ '^\d{4}$' THEN
        RETURN v::integer;
    ELSE
        RETURN NULL;
    END IF;
END;
$_$;


--
-- Name: legacy_yes_no_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_yes_no_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN legacy_clean_text(p_text) IS NULL THEN NULL
    WHEN upper(legacy_clean_text(p_text)) IN ('YES', 'Y', 'TRUE', '1') THEN TRUE
    WHEN upper(legacy_clean_text(p_text)) IN ('NO', 'N', 'FALSE', '0') THEN FALSE
    ELSE NULL
  END;
$$;


--
-- Name: legacy_yes_no_text_to_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legacy_yes_no_text_to_bool(p_text text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v text;
BEGIN
    v := upper(COALESCE(public.legacy_clean_text(p_text), ''));
    IF v IN ('YES', 'Y', 'TRUE', '1') THEN RETURN true; END IF;
    IF v IN ('NO', 'N', 'FALSE', '0') THEN RETURN false; END IF;
    RETURN NULL;
END;
$$;


--
-- Name: pe2024_bool(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('TRUE','YES','Y','1','CHECKED') THEN true
        WHEN upper(trim(coalesce(p_text, ''))) IN ('FALSE','NO','N','0','UNCHECKED') THEN false
        ELSE NULL
    END;
$$;


--
-- Name: pe2024_clean_line(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_clean_line(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(trim(regexp_replace(coalesce(p_text, ''), '[\t ]+', ' ', 'g')), '');
$$;


--
-- Name: pe2024_line_count_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_line_count_raw(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT count(*)::integer
    FROM public.pe2024_split_lines_raw(p_text);
$$;


--
-- Name: pe2024_line_value(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_line_value(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.pe2024_nullif_legacy_null(value)
    FROM public.pe2024_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: pe2024_line_value_raw(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_line_value_raw(p_text text, p_line_order integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT value
    FROM public.pe2024_split_lines_raw(p_text)
    WHERE line_order = p_line_order
    LIMIT 1;
$$;


--
-- Name: pe2024_make_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_make_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT left(
        trim(both '_' from regexp_replace(upper(coalesce(p_text, 'UNKNOWN')), '[^A-Z0-9]+', '_', 'g')),
        500
    );
$$;


--
-- Name: pe2024_normalize_prosecutor(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_normalize_prosecutor(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) IN ('PARRA', 'ASPP PARRA') THEN 'APP PARRA'
        WHEN upper(trim(coalesce(p_text, ''))) = 'ASCP TAMONDONG' THEN 'ACP TAMONDONG'
        ELSE upper(trim(coalesce(p_text, '')))
    END;
$$;


--
-- Name: pe2024_normalize_status_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_normalize_status_code(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.pe2024_make_code(
        CASE
            WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
            WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
            ELSE coalesce(p_text, 'UNKNOWN')
        END
    );
$$;


--
-- Name: pe2024_normalize_status_label(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_normalize_status_label(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN upper(trim(coalesce(p_text, ''))) = 'MIXED RESULT' THEN 'MIXED_RESULT'
        WHEN upper(trim(coalesce(p_text, ''))) = 'DISMISSSED' THEN 'DISMISSED'
        ELSE public.pe2024_clean_line(p_text)
    END;
$$;


--
-- Name: pe2024_nullif_legacy_null(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_nullif_legacy_null(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN public.pe2024_clean_line(p_text) IS NULL THEN NULL
        WHEN lower(public.pe2024_clean_line(p_text)) = 'null' THEN NULL
        ELSE public.pe2024_clean_line(p_text)
    END;
$$;


--
-- Name: pe2024_parse_docket_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_parse_docket_number(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(substring(coalesce(p_text, '') from '^\s*0*([0-9]+)'), '')::integer;
$$;


--
-- Name: pe2024_parse_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_parse_year(p_text text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})') IS NULL THEN NULL
        WHEN substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer < 100
            THEN 2000 + substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
        ELSE substring(coalesce(p_text, '') from '([0-9]{1,4})')::integer
    END;
$$;


--
-- Name: pe2024_split_lines(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_split_lines(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT line_order,
           public.pe2024_nullif_legacy_null(value) AS value
    FROM public.pe2024_split_lines_raw(p_text)
    WHERE public.pe2024_nullif_legacy_null(value) IS NOT NULL;
$$;


--
-- Name: pe2024_split_lines_raw(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_split_lines_raw(p_text text) RETURNS TABLE(line_order integer, value text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.pe2024_clean_line(raw_line) AS value
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.pe2024_clean_line(raw_line) IS NOT NULL;
$$;


--
-- Name: pe2024_split_persons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_split_persons(p_text text) RETURNS TABLE(line_order integer, full_name text)
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT ordinality::integer AS line_order,
           public.pe2024_strip_person_number(raw_line) AS full_name
    FROM regexp_split_to_table(coalesce(p_text, ''), E'\\r?\\n+') WITH ORDINALITY AS t(raw_line, ordinality)
    WHERE public.pe2024_nullif_legacy_null(public.pe2024_strip_person_number(raw_line)) IS NOT NULL;
$$;


--
-- Name: pe2024_strip_person_number(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_strip_person_number(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT public.pe2024_clean_line(
        regexp_replace(
            coalesce(p_text, ''),
            '^\s*(\(?[0-9]+\)?\s*([.)\-:]|\s+))+',
            '',
            'g'
        )
    );
$$;


--
-- Name: pe2024_try_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pe2024_try_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    v text;
    parts text[];
    y integer;
    m integer;
    d integer;
BEGIN
    v := public.pe2024_nullif_legacy_null(p_text);
    IF v IS NULL THEN
        RETURN NULL;
    END IF;

    v := regexp_replace(v, '\s*[,;]+\s*$', '', 'g');

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    IF v ~ '^\d{1,2}/\d{1,2}/\d{2,4}$' THEN
        parts := regexp_split_to_array(v, '/');
        y := parts[3]::integer;
        IF y < 100 THEN
            y := 2000 + y;
        END IF;
        m := parts[1]::integer;
        d := parts[2]::integer;
        RETURN make_date(y, m, d);
    END IF;

    IF v ~ '^\d{4,5}(\.\d+)?$' THEN
        RETURN date '1899-12-30' + (v::numeric::integer);
    END IF;

    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$_$;


--
-- Name: raise_exception(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.raise_exception(p_message text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION '%', p_message;
END;
$$;


--
-- Name: refresh_clearance_phonetic_name_tokens(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_clearance_phonetic_name_tokens() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  TRUNCATE TABLE public.clearance_phonetic_name_tokens;

  -- Persons.full_name tokens
  INSERT INTO public.clearance_phonetic_name_tokens (
    person_id,
    source_table,
    source_column,
    source_value,
    token,
    token_order,
    token_len,
    phonetic_primary,
    phonetic_alt,
    phonetic_codes
  )
  SELECT
    p.id,
    'persons',
    'full_name',
    p.full_name,
    tok.token,
    tok.token_order::integer,
    length(tok.token),
    dmetaphone(tok.token),
    dmetaphone_alt(tok.token),
    public.clearance_phonetic_codes(tok.token)
  FROM public.persons p
  CROSS JOIN LATERAL regexp_split_to_table(
    public.clearance_exact_norm(p.full_name),
    ' '
  ) WITH ORDINALITY AS tok(token, token_order)
  WHERE coalesce(p.is_active, true) = true
    AND length(tok.token) >= 3
    AND cardinality(public.clearance_phonetic_codes(tok.token)) > 0;

  -- Structured aliases, if present
  INSERT INTO public.clearance_phonetic_name_tokens (
    person_id,
    source_table,
    source_column,
    source_value,
    token,
    token_order,
    token_len,
    phonetic_primary,
    phonetic_alt,
    phonetic_codes
  )
  SELECT
    pa.person_id,
    'person_aliases',
    'alias_name',
    pa.alias_name,
    tok.token,
    tok.token_order::integer,
    length(tok.token),
    dmetaphone(tok.token),
    dmetaphone_alt(tok.token),
    public.clearance_phonetic_codes(tok.token)
  FROM public.person_aliases pa
  JOIN public.persons p ON p.id = pa.person_id
  CROSS JOIN LATERAL regexp_split_to_table(
    public.clearance_exact_norm(pa.alias_name),
    ' '
  ) WITH ORDINALITY AS tok(token, token_order)
  WHERE coalesce(pa.is_active, true) = true
    AND coalesce(p.is_active, true) = true
    AND length(tok.token) >= 3
    AND cardinality(public.clearance_phonetic_codes(tok.token)) > 0;
END;
$$;


--
-- Name: refresh_clearance_possible_name_tokens(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_clearance_possible_name_tokens() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  TRUNCATE TABLE public.clearance_possible_name_tokens;

  INSERT INTO public.clearance_possible_name_tokens (
    person_id,
    source_table,
    source_column,
    source_value,
    token,
    token_order,
    token_len,
    first_char,
    first2,
    first3,
    last2,
    last3,
    ck_key,
    bv_key,
    phf_key,
    sz_key,
    skeleton
  )
  SELECT
    p.id,
    'persons',
    'full_name',
    p.full_name,
    tok.token,
    tok.token_order::integer,
    length(tok.token),
    left(tok.token, 1),
    left(tok.token, 2),
    left(tok.token, 3),
    right(tok.token, 2),
    right(tok.token, 3),
    public.clearance_ck_key(tok.token),
    public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token),
    public.clearance_sz_key(tok.token),
    public.clearance_token_skeleton(tok.token)
  FROM public.persons p
  CROSS JOIN LATERAL regexp_split_to_table(
    public.clearance_exact_norm(p.full_name),
    ' '
  ) WITH ORDINALITY AS tok(token, token_order)
  WHERE coalesce(p.is_active, true) = true
    AND length(tok.token) > 1;

  INSERT INTO public.clearance_possible_name_tokens (
    person_id,
    source_table,
    source_column,
    source_value,
    token,
    token_order,
    token_len,
    first_char,
    first2,
    first3,
    last2,
    last3,
    ck_key,
    bv_key,
    phf_key,
    sz_key,
    skeleton
  )
  SELECT
    pa.person_id,
    'person_aliases',
    'alias_name',
    pa.alias_name,
    tok.token,
    tok.token_order::integer,
    length(tok.token),
    left(tok.token, 1),
    left(tok.token, 2),
    left(tok.token, 3),
    right(tok.token, 2),
    right(tok.token, 3),
    public.clearance_ck_key(tok.token),
    public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token),
    public.clearance_sz_key(tok.token),
    public.clearance_token_skeleton(tok.token)
  FROM public.person_aliases pa
  JOIN public.persons p ON p.id = pa.person_id
  CROSS JOIN LATERAL regexp_split_to_table(
    public.clearance_exact_norm(pa.alias_name),
    ' '
  ) WITH ORDINALITY AS tok(token, token_order)
  WHERE coalesce(pa.is_active, true) = true
    AND coalesce(p.is_active, true) = true
    AND length(tok.token) > 1;
END;
$$;


--
-- Name: search_clearance_phonetic_matches(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_phonetic_matches(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
    LANGUAGE sql STABLE
    AS $$
  WITH normalized AS (
    SELECT
      nullif(trim(p_query), '') AS q,
      public.clearance_exact_norm(p_query) AS q_norm,
      public.clearance_exact_tokens(p_query) AS q_tokens,
      CASE
        WHEN p_search_type IN ('name', 'alias', 'all') THEN p_search_type
        ELSE 'all'
      END AS search_type,
      least(greatest(coalesce(p_limit, 50), 1), 100) AS safe_limit
  ),

  query_tokens AS MATERIALIZED (
    SELECT DISTINCT
      u.token,
      public.clearance_phonetic_codes(u.token) AS phonetic_codes
    FROM normalized n
    CROSS JOIN LATERAL unnest(n.q_tokens) AS u(token)
    WHERE n.q IS NOT NULL
      AND length(u.token) >= 3
      AND cardinality(public.clearance_phonetic_codes(u.token)) > 0
  ),

  query_token_count AS (
    SELECT count(*)::integer AS query_token_count
    FROM query_tokens
  ),

  raw_phonetic_hits AS MATERIALIZED (
    SELECT
      t.person_id,
      q.token AS query_token,
      t.token AS matched_token,
      t.source_table,

      CASE
        WHEN t.token = q.token THEN 'exact_token'
        ELSE 'phonetic'
      END AS hit_type

    FROM query_tokens q
    JOIN public.clearance_phonetic_name_tokens t
      ON t.phonetic_codes && q.phonetic_codes
    JOIN normalized n ON true
    WHERE (
        n.search_type = 'all'
        OR (n.search_type = 'name' AND t.source_table = 'persons')
        OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
      )
  ),

  best_hits AS (
    SELECT
      person_id,
      query_token,
      (array_agg(matched_token ORDER BY CASE WHEN hit_type = 'exact_token' THEN 1 ELSE 2 END, matched_token))[1] AS best_matched_token,
      (array_agg(hit_type ORDER BY CASE WHEN hit_type = 'exact_token' THEN 1 ELSE 2 END, hit_type))[1] AS best_hit_type
    FROM raw_phonetic_hits
    GROUP BY person_id, query_token
  ),

  candidate_persons AS (
    SELECT
      b.person_id,
      count(DISTINCT b.query_token)::integer AS matched_query_token_count,
      string_agg(
        b.query_token || '≈' || b.best_matched_token || ' (' || b.best_hit_type || ')',
        ', '
        ORDER BY b.query_token
      ) AS match_reason
    FROM best_hits b
    CROSS JOIN query_token_count qtc
    GROUP BY b.person_id, qtc.query_token_count
    HAVING
      qtc.query_token_count >= 2
      AND count(DISTINCT b.query_token) >= 2
    ORDER BY
      count(DISTINCT b.query_token) DESC,
      b.person_id
    LIMIT 500
  ),

  base AS (
    SELECT
      p.id::integer AS person_id,
      c.id::integer AS case_id,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS docket_number,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS case_number,

      p.full_name,
      public.clearance_exact_norm(p.full_name) AS full_name_norm,
      public.clearance_exact_tokens(p.full_name) AS full_name_tokens,

      coalesce(alias_data.aliases, array[]::text[]) AS aliases,
      coalesce(cs.display_label, cs.code, 'Unknown') AS status,
      coalesce(c.updated_at, c.created_at, now()) AS last_updated,
      coalesce(pr.display_label, pr.code, 'Participant') AS role_label,

      age_data.age_text AS age,
      violation_data.violations AS violations,

      n.q,
      n.q_norm,
      n.q_tokens,
      n.search_type,
      n.safe_limit,

      cpers.matched_query_token_count,
      cpers.match_reason

    FROM normalized n
    JOIN candidate_persons cpers ON true

    JOIN public.persons p
      ON p.id = cpers.person_id
     AND coalesce(p.is_active, true) = true

    JOIN public.case_participants cp
      ON cp.person_id = p.id

    JOIN public.cases c
      ON c.id = cp.case_id
     AND coalesce(c.is_archived, false) = false

    JOIN public.docket_types dt
      ON dt.id = c.docket_type_id

    LEFT JOIN public.participant_roles pr
      ON pr.id = cp.role_id

    LEFT JOIN public.case_private_details cpd
      ON cpd.case_id = c.id

    LEFT JOIN public.case_statuses cs
      ON cs.id = cpd.current_status_id

    LEFT JOIN LATERAL (
      SELECT array_agg(pa.alias_name ORDER BY pa.alias_name) AS aliases
      FROM public.person_aliases pa
      WHERE pa.person_id = p.id
        AND coalesce(pa.is_active, true) = true
    ) alias_data ON true

    LEFT JOIN LATERAL (
      SELECT cpa.age_text
      FROM public.case_participant_attributes cpa
      WHERE cpa.case_participant_id = cp.id
      ORDER BY cpa.id DESC
      LIMIT 1
    ) age_data ON true

    LEFT JOIN LATERAL (
      SELECT string_agg(v.title, ', ' ORDER BY cv.violation_order, v.title) AS violations
      FROM public.case_violations cv
      JOIN public.violations v ON v.id = cv.violation_id
      WHERE cv.case_id = c.id
    ) violation_data ON true
  ),

  scored AS (
    SELECT
      b.*,

      CASE
        WHEN b.matched_query_token_count >= 4 THEN 70
        WHEN b.matched_query_token_count = 3 THEN 65
        WHEN b.matched_query_token_count = 2 THEN 60
        ELSE 0
      END AS score,

      'Sound-alike phonetic token match: ' || b.match_reason AS details

    FROM base b
  )

  SELECT
    s.person_id,
    s.case_id,
    s.docket_number,
    s.case_number,
    s.full_name,
    s.aliases,
    s.status,
    s.last_updated,
    s.score AS confidence_score,
    s.details AS match_details,
    'phonetic'::text AS match_type,
    s.role_label,
    s.age,
    s.violations
  FROM scored s
  WHERE s.score > 0

    -- Do not duplicate exact all-token matches from Phase 1
    AND NOT (
      s.search_type IN ('name', 'all')
      AND (
        s.full_name_norm = s.q_norm
        OR s.q_tokens <@ s.full_name_tokens
      )
    )

  ORDER BY
    s.score DESC,
    s.full_name,
    s.case_id

  LIMIT (SELECT safe_limit FROM normalized);
$$;


--
-- Name: search_clearance_possible_matches(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_possible_matches(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
    LANGUAGE sql STABLE
    AS $$
  SELECT *
  FROM public.search_clearance_possible_matches_v31(p_query, p_search_type, p_limit);
$$;


--
-- Name: search_clearance_possible_matches_v3(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_possible_matches_v3(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
    LANGUAGE sql STABLE
    AS $$
  WITH normalized AS (
    SELECT
      nullif(trim(p_query), '') AS q,
      public.clearance_exact_norm(p_query) AS q_norm,
      public.clearance_exact_tokens(p_query) AS q_tokens,
      cardinality(public.clearance_exact_tokens(p_query)) AS q_token_count,
      CASE
        WHEN p_search_type IN ('name', 'alias', 'all') THEN p_search_type
        ELSE 'all'
      END AS search_type,
      least(greatest(coalesce(p_limit, 50), 1), 100) AS safe_limit
  ),

  query_tokens AS (
    SELECT
      u.token,
      u.token_order::integer,
      length(u.token) AS token_len,
      left(u.token, 1) AS first_char,
      left(u.token, 2) AS first2,
      left(u.token, 3) AS first3,
      right(u.token, 2) AS last2,
      right(u.token, 3) AS last3,
      public.clearance_ck_key(u.token) AS ck_key,
      public.clearance_bv_key(u.token) AS bv_key,
      public.clearance_phf_key(u.token) AS phf_key,
      public.clearance_sz_key(u.token) AS sz_key,
      public.clearance_token_skeleton(u.token) AS skeleton
    FROM normalized n
    CROSS JOIN LATERAL unnest(n.q_tokens) WITH ORDINALITY AS u(token, token_order)
  ),

  raw_token_candidates AS MATERIALIZED (
    -- Exact token candidates
    SELECT
      q.token AS query_token,
      t.person_id,
      t.token AS matched_token,
      t.source_table,
      'exact'::text AS raw_reason,
      1 AS raw_priority
    FROM query_tokens q
    JOIN public.clearance_possible_name_tokens t
      ON t.token = q.token
    JOIN normalized n ON true
    WHERE n.q IS NOT NULL
      AND (
        n.search_type = 'all'
        OR (n.search_type = 'name' AND t.source_table = 'persons')
        OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
      )

    UNION ALL

    -- Exact variant-key candidates
    SELECT
      q.token AS query_token,
      t.person_id,
      t.token AS matched_token,
      t.source_table,
      'variant_key'::text AS raw_reason,
      2 AS raw_priority
    FROM query_tokens q
    JOIN public.clearance_possible_name_tokens t
      ON (
        t.ck_key = q.ck_key
        OR t.bv_key = q.bv_key
        OR t.phf_key = q.phf_key
        OR t.sz_key = q.sz_key
      )
     AND t.token <> q.token
    JOIN normalized n ON true
    WHERE n.q IS NOT NULL
      AND q.token_len >= 3
      AND (
        n.search_type = 'all'
        OR (n.search_type = 'name' AND t.source_table = 'persons')
        OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
      )

    UNION ALL

    -- Cheap blocked candidates
    SELECT
      q.token AS query_token,
      blocked.person_id,
      blocked.token AS matched_token,
      blocked.source_table,
      blocked.raw_reason,
      blocked.raw_priority
    FROM query_tokens q
    CROSS JOIN LATERAL (
      SELECT
        t.person_id,
        t.token,
        t.source_table,
        CASE
          WHEN t.first3 = q.first3 THEN 'same_first3'
          WHEN t.first2 = q.first2 THEN 'same_first2'
          WHEN t.skeleton = q.skeleton THEN 'same_skeleton'
          WHEN t.last3 = q.last3 THEN 'same_last3'
          WHEN t.last2 = q.last2 THEN 'same_last2'
          WHEN t.token % q.token THEN 'trigram_token'
          WHEN t.ck_key % q.ck_key THEN 'trigram_ck'
          WHEN t.bv_key % q.bv_key THEN 'trigram_bv'
          WHEN t.phf_key % q.phf_key THEN 'trigram_phf'
          WHEN t.sz_key % q.sz_key THEN 'trigram_sz'
          ELSE 'blocked'
        END AS raw_reason,
        CASE
          WHEN t.first3 = q.first3 THEN 3
          WHEN t.first2 = q.first2 THEN 4
          WHEN t.skeleton = q.skeleton THEN 5
          WHEN t.last3 = q.last3 THEN 6
          WHEN t.last2 = q.last2 THEN 7
          ELSE 8
        END AS raw_priority
      FROM public.clearance_possible_name_tokens t
      JOIN normalized n ON true
      WHERE n.q IS NOT NULL
        AND q.token_len >= 3
        AND t.token_len BETWEEN greatest(q.token_len - 2, 1) AND q.token_len + 2
        AND (
          t.first3 = q.first3
          OR t.first2 = q.first2
          OR t.skeleton = q.skeleton
          OR t.last3 = q.last3
          OR t.last2 = q.last2
          OR t.token % q.token
          OR t.ck_key % q.ck_key
          OR t.bv_key % q.bv_key
          OR t.phf_key % q.phf_key
          OR t.sz_key % q.sz_key
        )
        AND (
          n.search_type = 'all'
          OR (n.search_type = 'name' AND t.source_table = 'persons')
          OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
        )
      ORDER BY
        raw_priority,
        abs(t.token_len - q.token_len),
        t.token
      LIMIT 80
    ) blocked
  ),

  scored_token_candidates AS MATERIALIZED (
    SELECT
      rtc.query_token,
      rtc.person_id,
      rtc.matched_token,
      rtc.raw_reason,
      round(
        public.clearance_possible_token_score_v3(
          rtc.query_token,
          rtc.matched_token
        ) * 100
      )::integer AS token_score
    FROM raw_token_candidates rtc
  ),

  best_token_per_person AS (
    SELECT
      person_id,
      query_token,
      max(token_score) AS best_token_score,
      (array_agg(matched_token ORDER BY token_score DESC, matched_token))[1] AS best_matched_token,
      (array_agg(raw_reason ORDER BY token_score DESC, raw_reason))[1] AS best_reason
    FROM scored_token_candidates
    WHERE token_score >= 60
    GROUP BY person_id, query_token
  ),

  candidate_persons AS (
    SELECT
      b.person_id,
      count(*) AS matched_query_token_count,
      min(b.best_token_score) AS min_token_score,
      max(b.best_token_score) AS max_token_score,
      string_agg(
        b.query_token || '≈' || b.best_matched_token || ' (' || b.best_reason || ' ' || b.best_token_score::text || ')',
        ', '
        ORDER BY b.query_token
      ) AS match_reason
    FROM best_token_per_person b
    JOIN normalized n ON true
    GROUP BY b.person_id, n.q_token_count
    HAVING
      (
        n.q_token_count >= 2
        AND count(*) = n.q_token_count
        AND min(b.best_token_score) >= 60
        AND max(b.best_token_score) >= 85
      )
      OR
      (
        n.q_token_count = 1
        AND max(b.best_token_score) >= 75
      )
    ORDER BY
      count(*) DESC,
      min(b.best_token_score) DESC,
      max(b.best_token_score) DESC,
      b.person_id
    LIMIT 200
  ),

  base AS (
    SELECT
      p.id::integer AS person_id,
      c.id::integer AS case_id,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS docket_number,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS case_number,

      p.full_name,
      public.clearance_exact_norm(p.full_name) AS full_name_norm,
      public.clearance_exact_tokens(p.full_name) AS full_name_tokens,

      coalesce(alias_data.aliases, array[]::text[]) AS aliases,
      coalesce(cs.display_label, cs.code, 'Unknown') AS status,
      coalesce(c.updated_at, c.created_at, now()) AS last_updated,
      coalesce(pr.display_label, pr.code, 'Participant') AS role_label,

      age_data.age_text AS age,
      violation_data.violations AS violations,

      n.q,
      n.q_norm,
      n.q_tokens,
      n.q_token_count,
      n.search_type,
      n.safe_limit,

      cpers.matched_query_token_count,
      cpers.min_token_score,
      cpers.max_token_score,
      cpers.match_reason

    FROM normalized n
    JOIN candidate_persons cpers ON true
    JOIN public.persons p
      ON p.id = cpers.person_id
     AND coalesce(p.is_active, true) = true

    JOIN public.case_participants cp
      ON cp.person_id = p.id

    JOIN public.cases c
      ON c.id = cp.case_id
     AND coalesce(c.is_archived, false) = false

    JOIN public.docket_types dt
      ON dt.id = c.docket_type_id

    LEFT JOIN public.participant_roles pr
      ON pr.id = cp.role_id

    LEFT JOIN public.case_private_details cpd
      ON cpd.case_id = c.id

    LEFT JOIN public.case_statuses cs
      ON cs.id = cpd.current_status_id

    LEFT JOIN LATERAL (
      SELECT array_agg(pa.alias_name ORDER BY pa.alias_name) AS aliases
      FROM public.person_aliases pa
      WHERE pa.person_id = p.id
        AND coalesce(pa.is_active, true) = true
    ) alias_data ON true

    LEFT JOIN LATERAL (
      SELECT cpa.age_text
      FROM public.case_participant_attributes cpa
      WHERE cpa.case_participant_id = cp.id
      ORDER BY cpa.id DESC
      LIMIT 1
    ) age_data ON true

    LEFT JOIN LATERAL (
      SELECT string_agg(v.title, ', ' ORDER BY cv.violation_order, v.title) AS violations
      FROM public.case_violations cv
      JOIN public.violations v ON v.id = cv.violation_id
      WHERE cv.case_id = c.id
    ) violation_data ON true
  ),

  scored AS (
    SELECT
      b.*,

      CASE
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 90 THEN 85
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 75 THEN 82
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 60 THEN 78
        WHEN b.q_token_count = 1 AND b.max_token_score >= 75 THEN 55
        ELSE 0
      END AS score,

      CASE
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 90
          THEN 'Possible spelling variant match: ' || b.match_reason
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 75
          THEN 'Possible edit-distance typo match: ' || b.match_reason
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 60
          THEN 'Possible misspelled name-token match: ' || b.match_reason
        WHEN b.q_token_count = 1 AND b.max_token_score >= 75
          THEN 'Possible single-token typo match: ' || b.match_reason
        ELSE 'Possible match'
      END AS details,

      CASE
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 90 THEN 'variant'
        ELSE 'fuzzy'
      END AS result_match_type

    FROM base b
  )

  SELECT
    s.person_id,
    s.case_id,
    s.docket_number,
    s.case_number,
    s.full_name,
    s.aliases,
    s.status,
    s.last_updated,
    s.score AS confidence_score,
    s.details AS match_details,
    s.result_match_type AS match_type,
    s.role_label,
    s.age,
    s.violations
  FROM scored s
  WHERE s.score > 0
    AND NOT (
      s.search_type IN ('name', 'all')
      AND (
        s.full_name_norm = s.q_norm
        OR (s.q_token_count >= 2 AND s.q_tokens <@ s.full_name_tokens)
      )
    )
  ORDER BY
    s.score DESC,
    s.full_name,
    s.case_id
  LIMIT (SELECT safe_limit FROM normalized);
$$;


--
-- Name: search_clearance_possible_matches_v31(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_possible_matches_v31(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
    LANGUAGE sql STABLE
    AS $$
  WITH normalized AS (
    SELECT
      nullif(trim(p_query), '') AS q,
      public.clearance_exact_norm(p_query) AS q_norm,
      public.clearance_exact_tokens(p_query) AS q_tokens,
      cardinality(public.clearance_exact_tokens(p_query)) AS q_token_count,
      CASE
        WHEN p_search_type IN ('name', 'alias', 'all') THEN p_search_type
        ELSE 'all'
      END AS search_type,
      least(greatest(coalesce(p_limit, 50), 1), 100) AS safe_limit
  ),

  query_tokens AS (
    SELECT
      u.token,
      u.token_order::integer,
      length(u.token) AS token_len,
      left(u.token, 1) AS first_char,
      left(u.token, 2) AS first2,
      left(u.token, 3) AS first3,
      right(u.token, 2) AS last2,
      right(u.token, 3) AS last3,
      public.clearance_ck_key(u.token) AS ck_key,
      public.clearance_bv_key(u.token) AS bv_key,
      public.clearance_phf_key(u.token) AS phf_key,
      public.clearance_sz_key(u.token) AS sz_key,
      public.clearance_token_skeleton(u.token) AS skeleton
    FROM normalized n
    CROSS JOIN LATERAL unnest(n.q_tokens) WITH ORDINALITY AS u(token, token_order)
  ),

  -- Persons with at least one exact or strong variant token match.
  -- Example: REYES anchors possible REINEL/PORTUGUES search.
  anchor_persons AS MATERIALIZED (
    SELECT DISTINCT
      t.person_id
    FROM query_tokens q
    JOIN public.clearance_possible_name_tokens t
      ON (
        t.token = q.token
        OR t.ck_key = q.ck_key
        OR t.bv_key = q.bv_key
        OR t.phf_key = q.phf_key
        OR t.sz_key = q.sz_key
      )
    JOIN normalized n ON true
    WHERE n.q IS NOT NULL
      AND (
        n.search_type = 'all'
        OR (n.search_type = 'name' AND t.source_table = 'persons')
        OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
      )
    ORDER BY t.person_id
    LIMIT 2000
  ),

  raw_token_candidates AS MATERIALIZED (
    -- Exact token candidates
    SELECT
      q.token AS query_token,
      t.person_id,
      t.token AS matched_token,
      t.source_table,
      'exact'::text AS raw_reason,
      1 AS raw_priority
    FROM query_tokens q
    JOIN public.clearance_possible_name_tokens t
      ON t.token = q.token
    JOIN normalized n ON true
    WHERE n.q IS NOT NULL
      AND (
        n.search_type = 'all'
        OR (n.search_type = 'name' AND t.source_table = 'persons')
        OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
      )

    UNION ALL

    -- Exact variant-key candidates
    SELECT
      q.token AS query_token,
      t.person_id,
      t.token AS matched_token,
      t.source_table,
      'variant_key'::text AS raw_reason,
      2 AS raw_priority
    FROM query_tokens q
    JOIN public.clearance_possible_name_tokens t
      ON (
        t.ck_key = q.ck_key
        OR t.bv_key = q.bv_key
        OR t.phf_key = q.phf_key
        OR t.sz_key = q.sz_key
      )
     AND t.token <> q.token
    JOIN normalized n ON true
    WHERE n.q IS NOT NULL
      AND q.token_len >= 3
      AND (
        n.search_type = 'all'
        OR (n.search_type = 'name' AND t.source_table = 'persons')
        OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
      )

    UNION ALL

    -- NEW: anchored candidates.
    -- If one token matches exactly, compare the other query tokens only
    -- against tokens belonging to those anchored persons.
    SELECT
      q.token AS query_token,
      t.person_id,
      t.token AS matched_token,
      t.source_table,
      CASE
        WHEN t.first3 = q.first3 THEN 'anchor_same_first3'
        WHEN t.first2 = q.first2 THEN 'anchor_same_first2'
        WHEN t.skeleton = q.skeleton THEN 'anchor_same_skeleton'
        WHEN t.last3 = q.last3 THEN 'anchor_same_last3'
        WHEN t.last2 = q.last2 THEN 'anchor_same_last2'
        WHEN left(t.token, 1) = q.first_char THEN 'anchor_same_first_char'
        ELSE 'anchor_candidate'
      END AS raw_reason,
      CASE
        WHEN t.first3 = q.first3 THEN 3
        WHEN t.first2 = q.first2 THEN 4
        WHEN t.skeleton = q.skeleton THEN 5
        WHEN t.last3 = q.last3 THEN 6
        WHEN t.last2 = q.last2 THEN 7
        WHEN left(t.token, 1) = q.first_char THEN 8
        ELSE 9
      END AS raw_priority
    FROM query_tokens q
    JOIN anchor_persons ap ON true
    JOIN public.clearance_possible_name_tokens t
      ON t.person_id = ap.person_id
    JOIN normalized n ON true
    WHERE n.q IS NOT NULL
      AND q.token_len >= 3
      AND t.token_len BETWEEN greatest(q.token_len - 2, 1) AND q.token_len + 2
      AND (
        t.first3 = q.first3
        OR t.first2 = q.first2
        OR t.skeleton = q.skeleton
        OR t.last3 = q.last3
        OR t.last2 = q.last2
        OR left(t.token, 1) = q.first_char
        OR t.token % q.token
        OR t.ck_key % q.ck_key
        OR t.bv_key % q.bv_key
        OR t.phf_key % q.phf_key
        OR t.sz_key % q.sz_key
      )
      AND (
        n.search_type = 'all'
        OR (n.search_type = 'name' AND t.source_table = 'persons')
        OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
      )

    UNION ALL

    -- Generic cheap blocked candidates, still limited per query token.
    SELECT
      q.token AS query_token,
      blocked.person_id,
      blocked.token AS matched_token,
      blocked.source_table,
      blocked.raw_reason,
      blocked.raw_priority
    FROM query_tokens q
    CROSS JOIN LATERAL (
      SELECT
        t.person_id,
        t.token,
        t.source_table,
        CASE
          WHEN t.first3 = q.first3 THEN 'same_first3'
          WHEN t.first2 = q.first2 THEN 'same_first2'
          WHEN t.skeleton = q.skeleton THEN 'same_skeleton'
          WHEN t.last3 = q.last3 THEN 'same_last3'
          WHEN t.last2 = q.last2 THEN 'same_last2'
          WHEN t.token % q.token THEN 'trigram_token'
          WHEN t.ck_key % q.ck_key THEN 'trigram_ck'
          WHEN t.bv_key % q.bv_key THEN 'trigram_bv'
          WHEN t.phf_key % q.phf_key THEN 'trigram_phf'
          WHEN t.sz_key % q.sz_key THEN 'trigram_sz'
          ELSE 'blocked'
        END AS raw_reason,
        CASE
          WHEN t.first3 = q.first3 THEN 3
          WHEN t.first2 = q.first2 THEN 4
          WHEN t.skeleton = q.skeleton THEN 5
          WHEN t.last3 = q.last3 THEN 6
          WHEN t.last2 = q.last2 THEN 7
          ELSE 8
        END AS raw_priority
      FROM public.clearance_possible_name_tokens t
      JOIN normalized n ON true
      WHERE n.q IS NOT NULL
        AND q.token_len >= 3
        AND t.token_len BETWEEN greatest(q.token_len - 2, 1) AND q.token_len + 2
        AND (
          t.first3 = q.first3
          OR t.first2 = q.first2
          OR t.skeleton = q.skeleton
          OR t.last3 = q.last3
          OR t.last2 = q.last2
          OR t.token % q.token
          OR t.ck_key % q.ck_key
          OR t.bv_key % q.bv_key
          OR t.phf_key % q.phf_key
          OR t.sz_key % q.sz_key
        )
        AND (
          n.search_type = 'all'
          OR (n.search_type = 'name' AND t.source_table = 'persons')
          OR (n.search_type = 'alias' AND t.source_table = 'person_aliases')
        )
      ORDER BY
        raw_priority,
        abs(t.token_len - q.token_len),
        t.token
      LIMIT 120
    ) blocked
  ),

  scored_token_candidates AS MATERIALIZED (
    SELECT
      rtc.query_token,
      rtc.person_id,
      rtc.matched_token,
      rtc.raw_reason,
      round(
        public.clearance_possible_token_score_v3(
          rtc.query_token,
          rtc.matched_token
        ) * 100
      )::integer AS token_score
    FROM raw_token_candidates rtc
  ),

  best_token_per_person AS (
    SELECT
      person_id,
      query_token,
      max(token_score) AS best_token_score,
      (array_agg(matched_token ORDER BY token_score DESC, matched_token))[1] AS best_matched_token,
      (array_agg(raw_reason ORDER BY token_score DESC, raw_reason))[1] AS best_reason
    FROM scored_token_candidates
    WHERE token_score >= 60
    GROUP BY person_id, query_token
  ),

  candidate_persons AS (
    SELECT
      b.person_id,
      count(*) AS matched_query_token_count,
      min(b.best_token_score) AS min_token_score,
      max(b.best_token_score) AS max_token_score,
      string_agg(
        b.query_token || '≈' || b.best_matched_token || ' (' || b.best_reason || ' ' || b.best_token_score::text || ')',
        ', '
        ORDER BY b.query_token
      ) AS match_reason
    FROM best_token_per_person b
    JOIN normalized n ON true
    GROUP BY b.person_id, n.q_token_count
    HAVING
      (
        n.q_token_count >= 2
        AND count(*) = n.q_token_count
        AND min(b.best_token_score) >= 60
        AND max(b.best_token_score) >= 85
      )
      OR
      (
        n.q_token_count = 1
        AND max(b.best_token_score) >= 75
      )
    ORDER BY
      count(*) DESC,
      min(b.best_token_score) DESC,
      max(b.best_token_score) DESC,
      b.person_id
    LIMIT 200
  ),

  base AS (
    SELECT
      p.id::integer AS person_id,
      c.id::integer AS case_id,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS docket_number,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS case_number,

      p.full_name,
      public.clearance_exact_norm(p.full_name) AS full_name_norm,
      public.clearance_exact_tokens(p.full_name) AS full_name_tokens,

      coalesce(alias_data.aliases, array[]::text[]) AS aliases,
      coalesce(cs.display_label, cs.code, 'Unknown') AS status,
      coalesce(c.updated_at, c.created_at, now()) AS last_updated,
      coalesce(pr.display_label, pr.code, 'Participant') AS role_label,

      age_data.age_text AS age,
      violation_data.violations AS violations,

      n.q,
      n.q_norm,
      n.q_tokens,
      n.q_token_count,
      n.search_type,
      n.safe_limit,

      cpers.matched_query_token_count,
      cpers.min_token_score,
      cpers.max_token_score,
      cpers.match_reason

    FROM normalized n
    JOIN candidate_persons cpers ON true
    JOIN public.persons p
      ON p.id = cpers.person_id
     AND coalesce(p.is_active, true) = true

    JOIN public.case_participants cp
      ON cp.person_id = p.id

    JOIN public.cases c
      ON c.id = cp.case_id
     AND coalesce(c.is_archived, false) = false

    JOIN public.docket_types dt
      ON dt.id = c.docket_type_id

    LEFT JOIN public.participant_roles pr
      ON pr.id = cp.role_id

    LEFT JOIN public.case_private_details cpd
      ON cpd.case_id = c.id

    LEFT JOIN public.case_statuses cs
      ON cs.id = cpd.current_status_id

    LEFT JOIN LATERAL (
      SELECT array_agg(pa.alias_name ORDER BY pa.alias_name) AS aliases
      FROM public.person_aliases pa
      WHERE pa.person_id = p.id
        AND coalesce(pa.is_active, true) = true
    ) alias_data ON true

    LEFT JOIN LATERAL (
      SELECT cpa.age_text
      FROM public.case_participant_attributes cpa
      WHERE cpa.case_participant_id = cp.id
      ORDER BY cpa.id DESC
      LIMIT 1
    ) age_data ON true

    LEFT JOIN LATERAL (
      SELECT string_agg(v.title, ', ' ORDER BY cv.violation_order, v.title) AS violations
      FROM public.case_violations cv
      JOIN public.violations v ON v.id = cv.violation_id
      WHERE cv.case_id = c.id
    ) violation_data ON true
  ),

  scored AS (
    SELECT
      b.*,

      CASE
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 90 THEN 85
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 75 THEN 82
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 60 THEN 78
        WHEN b.q_token_count = 1 AND b.max_token_score >= 75 THEN 55
        ELSE 0
      END AS score,

      CASE
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 90
          THEN 'Possible spelling variant match: ' || b.match_reason
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 75
          THEN 'Possible edit-distance typo match: ' || b.match_reason
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 60
          THEN 'Possible misspelled name-token match: ' || b.match_reason
        WHEN b.q_token_count = 1 AND b.max_token_score >= 75
          THEN 'Possible single-token typo match: ' || b.match_reason
        ELSE 'Possible match'
      END AS details,

      CASE
        WHEN b.q_token_count >= 2 AND b.min_token_score >= 90 THEN 'variant'
        ELSE 'fuzzy'
      END AS result_match_type

    FROM base b
  )

  SELECT
    s.person_id,
    s.case_id,
    s.docket_number,
    s.case_number,
    s.full_name,
    s.aliases,
    s.status,
    s.last_updated,
    s.score AS confidence_score,
    s.details AS match_details,
    s.result_match_type AS match_type,
    s.role_label,
    s.age,
    s.violations
  FROM scored s
  WHERE s.score > 0
    AND NOT (
      s.search_type IN ('name', 'all')
      AND (
        s.full_name_norm = s.q_norm
        OR (s.q_token_count >= 2 AND s.q_tokens <@ s.full_name_tokens)
      )
    )
  ORDER BY
    s.score DESC,
    s.full_name,
    s.case_id
  LIMIT (SELECT safe_limit FROM normalized);
$$;


--
-- Name: search_clearance_records(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_records(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
    LANGUAGE sql STABLE
    AS $$
  WITH normalized AS (
    SELECT
      nullif(trim(p_query), '') AS q,
      public.clearance_exact_norm(p_query) AS q_norm,
      public.clearance_exact_tokens(p_query) AS q_tokens,
      cardinality(public.clearance_exact_tokens(p_query)) AS q_token_count,
      CASE
        WHEN p_search_type IN ('name', 'alias', 'all') THEN p_search_type
        ELSE 'all'
      END AS search_type,
      least(greatest(coalesce(p_limit, 50), 1), 100) AS safe_limit
  ),
  base AS (
    SELECT
      p.id::integer AS person_id,
      c.id::integer AS case_id,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS docket_number,

      concat_ws(
        '-',
        dt.prefix,
        c.docket_year::text,
        nullif(c.docket_month_code, ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS case_number,

      p.full_name,
      public.clearance_exact_norm(p.full_name) AS full_name_norm,
      public.clearance_exact_tokens(p.full_name) AS full_name_tokens,

      coalesce(alias_data.aliases, array[]::text[]) AS aliases,
      coalesce(alias_data.alias_full_exact, false) AS alias_full_exact,
      coalesce(alias_data.alias_tokens_exact, false) AS alias_tokens_exact,
      coalesce(alias_data.alias_single_token_exact, false) AS alias_single_token_exact,
      alias_data.best_alias,

      coalesce(cs.display_label, cs.code, 'Pending') AS status,
      coalesce(c.updated_at, c.created_at, now()) AS last_updated,
      coalesce(pr.display_label, pr.code, 'Participant') AS role_label,

      age_data.age_text AS age,
      violation_data.violations AS violations,

      n.q,
      n.q_norm,
      n.q_tokens,
      n.q_token_count,
      n.search_type,
      n.safe_limit

    FROM normalized n
    JOIN public.persons p
      ON n.q IS NOT NULL
     AND p.is_active = true

    JOIN public.case_participants cp
      ON cp.person_id = p.id

    JOIN public.cases c
      ON c.id = cp.case_id
     AND coalesce(c.is_archived, false) = false

    JOIN public.docket_types dt
      ON dt.id = c.docket_type_id

    LEFT JOIN public.participant_roles pr
      ON pr.id = cp.role_id

    LEFT JOIN public.case_private_details cpd
      ON cpd.case_id = c.id

    LEFT JOIN public.case_statuses cs
      ON cs.id = cpd.current_status_id

    LEFT JOIN LATERAL (
      SELECT
        array_agg(pa.alias_name ORDER BY pa.alias_name) AS aliases,

        bool_or(public.clearance_exact_norm(pa.alias_name) = n.q_norm) AS alias_full_exact,

        bool_or(
          n.q_token_count > 0
          AND n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)
        ) AS alias_tokens_exact,

        bool_or(
          n.q_token_count = 1
          AND public.clearance_exact_tokens(pa.alias_name) && n.q_tokens
        ) AS alias_single_token_exact,

        (
          array_agg(
            pa.alias_name
            ORDER BY
              CASE
                WHEN public.clearance_exact_norm(pa.alias_name) = n.q_norm THEN 1
                WHEN n.q_token_count > 0
                  AND n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) THEN 2
                ELSE 3
              END,
              pa.alias_name
          )
        )[1] AS best_alias

      FROM public.person_aliases pa
      WHERE pa.person_id = p.id
        AND coalesce(pa.is_active, true) = true
    ) alias_data ON true

    LEFT JOIN LATERAL (
      SELECT cpa.age_text
      FROM public.case_participant_attributes cpa
      WHERE cpa.case_participant_id = cp.id
      ORDER BY cpa.id DESC
      LIMIT 1
    ) age_data ON true

    LEFT JOIN LATERAL (
      SELECT string_agg(v.title, ', ' ORDER BY cv.violation_order, v.title) AS violations
      FROM public.case_violations cv
      JOIN public.violations v ON v.id = cv.violation_id
      WHERE cv.case_id = c.id
    ) violation_data ON true
  ),
  scored AS (
    SELECT
      b.*,

      CASE
        WHEN b.search_type IN ('name', 'all')
          AND b.full_name_norm = b.q_norm
          THEN 100

        WHEN b.search_type IN ('name', 'all')
          AND b.q_token_count >= 2
          AND b.q_tokens <@ b.full_name_tokens
          THEN 95

        WHEN b.search_type IN ('alias', 'all')
          AND b.alias_full_exact
          THEN 92

        WHEN b.search_type IN ('alias', 'all')
          AND b.q_token_count >= 2
          AND b.alias_tokens_exact
          THEN 88

        WHEN b.search_type IN ('alias', 'all')
          AND b.q_token_count = 1
          AND b.alias_single_token_exact
          THEN 72

        WHEN b.search_type IN ('name', 'all')
          AND b.q_token_count = 1
          AND b.full_name_tokens && b.q_tokens
          THEN 65

        ELSE 0
      END AS score,

      CASE
        WHEN b.search_type IN ('name', 'all')
          AND b.full_name_norm = b.q_norm
          THEN 'Exact normalized full-name match'

        WHEN b.search_type IN ('name', 'all')
          AND b.q_token_count >= 2
          AND b.q_tokens <@ b.full_name_tokens
          THEN 'Exact name-token match: all searched name tokens exist in full name'

        WHEN b.search_type IN ('alias', 'all')
          AND b.alias_full_exact
          THEN 'Exact alias match: ' || coalesce(b.best_alias, '')

        WHEN b.search_type IN ('alias', 'all')
          AND b.q_token_count >= 2
          AND b.alias_tokens_exact
          THEN 'Exact alias-token match: ' || coalesce(b.best_alias, '')

        WHEN b.search_type IN ('alias', 'all')
          AND b.q_token_count = 1
          AND b.alias_single_token_exact
          THEN 'Exact alias single-token match: ' || coalesce(b.best_alias, '')

        WHEN b.search_type IN ('name', 'all')
          AND b.q_token_count = 1
          AND b.full_name_tokens && b.q_tokens
          THEN 'Exact single-token name match'

        ELSE 'No exact match'
      END AS details,

      CASE
        WHEN b.search_type IN ('alias', 'all')
          AND (b.alias_full_exact OR b.alias_tokens_exact OR b.alias_single_token_exact)
          THEN 'alias'
        ELSE 'exact'
      END AS result_match_type

    FROM base b
  )
  SELECT
    s.person_id,
    s.case_id,
    s.docket_number,
    s.case_number,
    s.full_name,
    s.aliases,
    s.status,
    s.last_updated,
    s.score AS confidence_score,
    s.details AS match_details,
    s.result_match_type AS match_type,
    s.role_label,
    s.age,
    s.violations
  FROM scored s
  WHERE s.score > 0
  ORDER BY
    s.score DESC,
    s.full_name,
    s.case_id
  LIMIT (SELECT safe_limit FROM normalized);
$$;


--
-- Name: set_updated_at_now(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at_now() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: trg_case_participant_relationships_same_case(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_case_participant_relationships_same_case() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_from_case_id integer;
    v_to_case_id integer;
BEGIN
    SELECT case_id INTO v_from_case_id
    FROM public.case_participants
    WHERE id = NEW.from_case_participant_id;

    SELECT case_id INTO v_to_case_id
    FROM public.case_participants
    WHERE id = NEW.to_case_participant_id;

    IF v_from_case_id IS NULL THEN
        RAISE EXCEPTION 'from_case_participant_id % does not exist', NEW.from_case_participant_id;
    END IF;

    IF v_to_case_id IS NULL THEN
        RAISE EXCEPTION 'to_case_participant_id % does not exist', NEW.to_case_participant_id;
    END IF;

    IF NEW.case_id <> v_from_case_id OR NEW.case_id <> v_to_case_id THEN
        RAISE EXCEPTION 'case_participant_relationships case_id mismatch. relationship case_id=%, from case_id=%, to case_id=%', NEW.case_id, v_from_case_id, v_to_case_id;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: void_case_event(bigint, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL::bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE public.case_events
    SET is_voided = true,
        void_reason = p_void_reason,
        voided_at = now(),
        voided_by_user_id = p_voided_by_user_id,
        updated_by_user_id = p_voided_by_user_id,
        updated_at = now()
    WHERE id = p_case_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'case_event_id % not found', p_case_event_id;
    END IF;
END;
$$;


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
    -- Regclass of the table e.g. public.notes
    entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

    -- I, U, D, T: insert, update ...
    action realtime.action = (
        case wal ->> 'action'
            when 'I' then 'INSERT'
            when 'U' then 'UPDATE'
            when 'D' then 'DELETE'
            else 'ERROR'
        end
    );

    -- Is row level security enabled for the table
    is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

    subscriptions realtime.subscription[] = array_agg(subs)
        from
            realtime.subscription subs
        where
            subs.entity = entity_
            -- Filter by action early - only get subscriptions interested in this action
            -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
            and (subs.action_filter = '*' or subs.action_filter = action::text);

    -- Subscription vars
    working_role regrole;
    working_selected_columns text[];
    claimed_role regrole;
    claims jsonb;

    subscription_id uuid;
    subscription_has_access bool;
    visible_to_subscription_ids uuid[] = '{}';

    -- structured info for wal's columns
    columns realtime.wal_column[];
    -- previous identity values for update/delete
    old_columns realtime.wal_column[];

    error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

    -- Primary jsonb output for record
    output jsonb;

    -- Loop record for iterating unique roles (outer loop)
    role_record record;
    -- Loop record for iterating unique selected_columns within a role (inner loop)
    cols_record record;
    -- Subscription ids visible at the role level (before fanning out by selected_columns)
    visible_role_sub_ids uuid[] = '{}';

begin
    perform set_config('role', null, true);

    columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'columns') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    old_columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'identity') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    for role_record in
        select claims_role
        from (select distinct claims_role from unnest(subscriptions)) t
        order by claims_role::text
    loop
        working_role := role_record.claims_role;

        -- Update `is_selectable` for columns and old_columns (once per role)
        columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(columns) c;

        old_columns =
                array_agg(
                    (
                        c.name,
                        c.type_name,
                        c.type_oid,
                        c.value,
                        c.is_pkey,
                        pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                    )::realtime.wal_column
                )
                from
                    unnest(old_columns) c;

        if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
            -- Fan out 400 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 400: Bad Request, no primary key']
                )::realtime.wal_rls;
            end loop;

        -- The claims role does not have SELECT permission to the primary key of entity
        elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
            -- Fan out 401 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 401: Unauthorized']
                )::realtime.wal_rls;
            end loop;

        else
            -- Create the prepared statement (once per role)
            if is_rls_enabled and action <> 'DELETE' then
                if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                    deallocate walrus_rls_stmt;
                end if;
                execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
            end if;

            -- Collect all visible subscription IDs for this role (filter check + RLS check)
            visible_role_sub_ids = '{}';

            for subscription_id, claims in (
                    select
                        subs.subscription_id,
                        subs.claims
                    from
                        unnest(subscriptions) subs
                    where
                        subs.entity = entity_
                        and subs.claims_role = working_role
                        and (
                            realtime.is_visible_through_filters(columns, subs.filters)
                            or (
                              action = 'DELETE'
                              and realtime.is_visible_through_filters(old_columns, subs.filters)
                            )
                        )
            ) loop

                if not is_rls_enabled or action = 'DELETE' then
                    visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                else
                    -- Check if RLS allows the role to see the record
                    perform
                        -- Trim leading and trailing quotes from working_role because set_config
                        -- doesn't recognize the role as valid if they are included
                        set_config('role', trim(both '"' from working_role::text), true),
                        set_config('request.jwt.claims', claims::text, true);

                    execute 'execute walrus_rls_stmt' into subscription_has_access;

                    if subscription_has_access then
                        visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                    end if;
                end if;
            end loop;

            perform set_config('role', null, true);

            -- Inner loop: per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;

                output = jsonb_build_object(
                    'schema', wal ->> 'schema',
                    'table', wal ->> 'table',
                    'type', action,
                    'commit_timestamp', to_char(
                        ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
                    ),
                    'columns', (
                        select
                            jsonb_agg(
                                jsonb_build_object(
                                    'name', pa.attname,
                                    'type', pt.typname
                                )
                                order by pa.attnum asc
                            )
                        from
                            pg_attribute pa
                            join pg_type pt
                                on pa.atttypid = pt.oid
                            left join (
                                select unnest(conkey) as pkey_attnum
                                from pg_constraint
                                where conrelid = entity_ and contype = 'p'
                            ) pk on pk.pkey_attnum = pa.attnum
                        where
                            attrelid = entity_
                            and attnum > 0
                            and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
                            and (working_selected_columns is null or pa.attname = any(working_selected_columns) or pk.pkey_attnum is not null)
                    )
                )
                -- Add "record" key for insert and update
                || case
                    when action in ('INSERT', 'UPDATE') then
                        jsonb_build_object(
                            'record',
                            (
                                select
                                    jsonb_object_agg(
                                        -- if unchanged toast, get column name and value from old record
                                        coalesce((c).name, (oc).name),
                                        case
                                            when (c).name is null then (oc).value
                                            else (c).value
                                        end
                                    )
                                from
                                    unnest(columns) c
                                    full outer join unnest(old_columns) oc
                                        on (c).name = (oc).name
                                where
                                    coalesce((c).is_selectable, (oc).is_selectable)
                                    and (working_selected_columns is null or coalesce((c).name, (oc).name) = any(working_selected_columns) or coalesce((c).is_pkey, (oc).is_pkey))
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            )
                        )
                    else '{}'::jsonb
                end
                -- Add "old_record" key for update and delete
                || case
                    when action = 'UPDATE' then
                        jsonb_build_object(
                                'old_record',
                                (
                                    select jsonb_object_agg((c).name, (c).value)
                                    from unnest(old_columns) c
                                    where
                                        (c).is_selectable
                                        and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                        and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                )
                            )
                    when action = 'DELETE' then
                        jsonb_build_object(
                            'old_record',
                            (
                                select jsonb_object_agg((c).name, (c).value)
                                from unnest(old_columns) c
                                where
                                    (c).is_selectable
                                    and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                    and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                            )
                        )
                    else '{}'::jsonb
                end;

                -- Filter visible_role_sub_ids to those matching the current selected_columns group
                visible_to_subscription_ids = coalesce(
                    (
                        select array_agg(s.subscription_id)
                        from unnest(subscriptions) s
                        where s.claims_role = working_role
                          and (s.selected_columns is not distinct from working_selected_columns)
                          and s.subscription_id = any(visible_role_sub_ids)
                    ),
                    '{}'::uuid[]
                );

                return next (
                    output,
                    is_rls_enabled,
                    visible_to_subscription_ids,
                    case
                        when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                        else '{}'
                    end
                )::realtime.wal_rls;
            end loop;

        end if;
    end loop;

    perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  res jsonb;
begin
  if type_::text = 'bytea' then
    return to_jsonb(val);
  end if;
  execute format('select to_jsonb(%L::'|| type_::text || ')', val) into res;
  return res;
end
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $_$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS TABLE(wal jsonb, is_rls_enabled boolean, subscription_ids uuid[], errors text[], slot_changes_count bigint)
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
  WITH pub AS (
    SELECT
      concat_ws(
        ',',
        CASE WHEN bool_or(pubinsert) THEN 'insert' ELSE NULL END,
        CASE WHEN bool_or(pubupdate) THEN 'update' ELSE NULL END,
        CASE WHEN bool_or(pubdelete) THEN 'delete' ELSE NULL END
      ) AS w2j_actions,
      coalesce(
        string_agg(
          realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
          ','
        ) filter (WHERE ppt.tablename IS NOT NULL),
        ''
      ) AS w2j_add_tables
    FROM pg_publication pp
    LEFT JOIN pg_publication_tables ppt ON pp.pubname = ppt.pubname
    WHERE pp.pubname = publication
    GROUP BY pp.pubname
    LIMIT 1
  ),
  -- MATERIALIZED ensures pg_logical_slot_get_changes is called exactly once
  w2j AS MATERIALIZED (
    SELECT x.*, pub.w2j_add_tables
    FROM pub,
         pg_logical_slot_get_changes(
           slot_name, null, max_changes,
           'include-pk', 'true',
           'include-transaction', 'false',
           'include-timestamp', 'true',
           'include-type-oids', 'true',
           'format-version', '2',
           'actions', pub.w2j_actions,
           'add-tables', pub.w2j_add_tables
         ) x
  ),
  slot_count AS (
    SELECT count(*)::bigint AS cnt
    FROM w2j
    WHERE w2j.w2j_add_tables <> ''
  ),
  rls_filtered AS (
    SELECT xyz.wal, xyz.is_rls_enabled, xyz.subscription_ids, xyz.errors
    FROM w2j,
         realtime.apply_rls(
           wal := w2j.data::jsonb,
           max_record_bytes := max_record_bytes
         ) xyz(wal, is_rls_enabled, subscription_ids, errors)
    WHERE w2j.w2j_add_tables <> ''
      AND xyz.subscription_ids[1] IS NOT NULL
  )
  SELECT rf.wal, rf.is_rls_enabled, rf.subscription_ids, rf.errors, sc.cnt
  FROM rls_filtered rf, slot_count sc

  UNION ALL

  SELECT null, null, null, null, sc.cnt
  FROM slot_count sc
  WHERE NOT EXISTS (SELECT 1 FROM rls_filtered)
$$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  SELECT
    realtime.wal2json_escape_identifier(nsp.nspname::text)
    || '.'
    || realtime.wal2json_escape_identifier(pc.relname::text)
  FROM pg_class pc
  JOIN pg_namespace nsp ON pc.relnamespace = nsp.oid
  WHERE pc.oid = entity
$$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: send_binary(bytea, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send_binary(payload bytea, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
BEGIN
  BEGIN
    generated_id := gen_random_uuid();

    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, binary_payload, event, topic, private, extension)
    VALUES (generated_id, payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    col_names text[] = coalesce(
            array_agg(c.column_name order by c.ordinal_position),
            '{}'::text[]
        )
        from
            information_schema.columns c
        where
            format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
            and pg_catalog.has_column_privilege(
                (new.claims ->> 'role'),
                format('%I.%I', c.table_schema, c.table_name)::regclass,
                c.column_name,
                'SELECT'
            );
    table_col_names text[] = coalesce(
            array_agg(pa.attname),
            '{}'::text[]
        )
        from
            pg_attribute pa
        where
            pa.attrelid = new.entity
            and pa.attnum > 0;
    filter realtime.user_defined_filter;
    col_type regtype;
    in_val jsonb;
    selected_col text;
begin
    for filter in select * from unnest(new.filters) loop
        -- Filtered column is valid
        if not filter.column_name = any(col_names) then
            raise exception 'invalid column for filter %', filter.column_name;
        end if;

        -- Type is sanitized and safe for string interpolation
        col_type = (
            select atttypid::regtype
            from pg_catalog.pg_attribute
            where attrelid = new.entity
                  and attname = filter.column_name
        );
        if col_type is null then
            raise exception 'failed to lookup type for column %', filter.column_name;
        end if;
        if filter.op = 'in'::realtime.equality_op then
            in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
            if coalesce(jsonb_array_length(in_val), 0) > 100 then
                raise exception 'too many values for `in` filter. Maximum 100';
            end if;
        else
            -- raises an exception if value is not coercable to type
            perform realtime.cast(filter.value, col_type);
        end if;
    end loop;

    -- Validate that selected_columns reference columns the role can SELECT
    if new.selected_columns is not null then
        for selected_col in select * from unnest(new.selected_columns) loop
            if not selected_col = any(col_names) then
                raise exception 'invalid column for select %', selected_col;
            end if;
        end loop;
    end if;

    -- Apply consistent order to filters so the unique constraint on
    -- (subscription_id, entity, filters) can't be tricked by a different filter order
    new.filters = coalesce(
        array_agg(f order by f.column_name, f.op, f.value),
        '{}'
    ) from unnest(new.filters) f;

    -- Normalize selected_columns order so ARRAY['a','b'] and ARRAY['b','a'] are
    -- treated as the same subscription group in apply_rls
    new.selected_columns = (
        select array_agg(c order by c)
        from unnest(new.selected_columns) c
    );

    return new;
end;
$$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: wal2json_escape_identifier(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.wal2json_escape_identifier(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  -- Prefix `\`, `,`, `.`, and any whitespace with `\`
  SELECT regexp_replace(name, '([\\,.[:space:]])', '\\\1', 'g')
$$;


--
-- Name: allow_any_operation(text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_any_operation(expected_operations text[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT CASE
      WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
      ELSE raw_operation
    END AS current_operation
    FROM current_operation
  )
  SELECT EXISTS (
    SELECT 1
    FROM normalized n
    CROSS JOIN LATERAL unnest(expected_operations) AS expected_operation
    WHERE expected_operation IS NOT NULL
      AND expected_operation <> ''
      AND n.current_operation = CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END
  );
$$;


--
-- Name: allow_only_operation(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_only_operation(expected_operation text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
        ELSE raw_operation
      END AS current_operation,
      CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END AS requested_operation
    FROM current_operation
  )
  SELECT CASE
    WHEN requested_operation IS NULL OR requested_operation = '' THEN FALSE
    ELSE COALESCE(current_operation = requested_operation, FALSE)
  END
  FROM normalized;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Get the last path segment (the actual filename)
    SELECT _parts[array_length(_parts, 1)] INTO _filename;
    -- Extract extension: reverse, split on '.', then reverse again
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_common_prefix(text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint)::bigint as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: protect_delete(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.protect_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: search_by_timestamp(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: custom_oauth_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.custom_oauth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type text NOT NULL,
    identifier text NOT NULL,
    name text NOT NULL,
    client_id text NOT NULL,
    client_secret text NOT NULL,
    acceptable_client_ids text[] DEFAULT '{}'::text[] NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    pkce_enabled boolean DEFAULT true NOT NULL,
    attribute_mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    email_optional boolean DEFAULT false NOT NULL,
    issuer text,
    discovery_url text,
    skip_nonce_check boolean DEFAULT false NOT NULL,
    cached_discovery jsonb,
    discovery_cached_at timestamp with time zone,
    authorization_url text,
    token_url text,
    userinfo_url text,
    jwks_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_oauth_providers_authorization_url_https CHECK (((authorization_url IS NULL) OR (authorization_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_authorization_url_length CHECK (((authorization_url IS NULL) OR (char_length(authorization_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_client_id_length CHECK (((char_length(client_id) >= 1) AND (char_length(client_id) <= 512))),
    CONSTRAINT custom_oauth_providers_discovery_url_length CHECK (((discovery_url IS NULL) OR (char_length(discovery_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_identifier_format CHECK ((identifier ~ '^[a-z0-9][a-z0-9:-]{0,48}[a-z0-9]$'::text)),
    CONSTRAINT custom_oauth_providers_issuer_length CHECK (((issuer IS NULL) OR ((char_length(issuer) >= 1) AND (char_length(issuer) <= 2048)))),
    CONSTRAINT custom_oauth_providers_jwks_uri_https CHECK (((jwks_uri IS NULL) OR (jwks_uri ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_jwks_uri_length CHECK (((jwks_uri IS NULL) OR (char_length(jwks_uri) <= 2048))),
    CONSTRAINT custom_oauth_providers_name_length CHECK (((char_length(name) >= 1) AND (char_length(name) <= 100))),
    CONSTRAINT custom_oauth_providers_oauth2_requires_endpoints CHECK (((provider_type <> 'oauth2'::text) OR ((authorization_url IS NOT NULL) AND (token_url IS NOT NULL) AND (userinfo_url IS NOT NULL)))),
    CONSTRAINT custom_oauth_providers_oidc_discovery_url_https CHECK (((provider_type <> 'oidc'::text) OR (discovery_url IS NULL) OR (discovery_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_issuer_https CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NULL) OR (issuer ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_requires_issuer CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NOT NULL))),
    CONSTRAINT custom_oauth_providers_provider_type_check CHECK ((provider_type = ANY (ARRAY['oauth2'::text, 'oidc'::text]))),
    CONSTRAINT custom_oauth_providers_token_url_https CHECK (((token_url IS NULL) OR (token_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_token_url_length CHECK (((token_url IS NULL) OR (char_length(token_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_userinfo_url_https CHECK (((userinfo_url IS NULL) OR (userinfo_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_userinfo_url_length CHECK (((userinfo_url IS NULL) OR (char_length(userinfo_url) <= 2048)))
);


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text,
    code_challenge_method auth.code_challenge_method,
    code_challenge text,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone,
    invite_token text,
    referrer text,
    oauth_client_state_id uuid,
    linking_target_id uuid,
    email_optional boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'Stores metadata for all OAuth/SSO login flows';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    token_endpoint_auth_method text NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)),
    CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: webauthn_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    challenge_type text NOT NULL,
    session_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT webauthn_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['signup'::text, 'registration'::text, 'authentication'::text])))
);


--
-- Name: webauthn_credentials; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    credential_id bytea NOT NULL,
    public_key bytea NOT NULL,
    attestation_type text DEFAULT ''::text NOT NULL,
    aaguid uuid,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    backup_eligible boolean DEFAULT false NOT NULL,
    backed_up boolean DEFAULT false NOT NULL,
    friendly_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


--
-- Name: address_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_types (
    id bigint NOT NULL,
    code text NOT NULL,
    display_label text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: address_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: address_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.address_types_id_seq OWNED BY public.address_types.id;


--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addresses (
    id bigint NOT NULL,
    line1 text,
    line2 text,
    barangay text,
    city text,
    province text,
    region text,
    zip_code text,
    country text DEFAULT 'Philippines'::character varying,
    latitude numeric(10,7),
    longitude numeric(10,7),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id bigint NOT NULL,
    actor_user_id bigint,
    entity_name text NOT NULL,
    entity_id bigint,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    ip_address text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_logs_id_seq OWNED BY public.audit_logs.id;


--
-- Name: case_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_addresses (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    address_id bigint NOT NULL,
    address_type_id bigint NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_addresses_id_seq OWNED BY public.case_addresses.id;


--
-- Name: case_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_assignments (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    prosecutor_id bigint NOT NULL,
    staff_id bigint,
    prosecutor_staff_assignment_id bigint,
    assigned_by_user_id bigint NOT NULL,
    assigned_at timestamp with time zone,
    unassigned_at timestamp with time zone,
    remarks text,
    legacy_date_raffled_raw text,
    case_event_id bigint
);


--
-- Name: COLUMN case_assignments.legacy_date_raffled_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_assignments.legacy_date_raffled_raw IS 'Original cleaned legacy Date Raffled to Prosecutor value for exact legacy export reconstruction.';


--
-- Name: case_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_assignments_id_seq OWNED BY public.case_assignments.id;


--
-- Name: case_attachment_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_attachment_index (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    gdrive_file_id character varying(255) NOT NULL,
    gdrive_parent_folder_id character varying(255) NOT NULL,
    file_name text NOT NULL,
    mime_type character varying(255),
    web_view_link character varying(2048),
    web_content_link character varying(2048),
    file_size_bytes bigint,
    md5_checksum character varying(128),
    modified_time timestamp with time zone,
    local_cache_path character varying(2048),
    is_available_offline boolean DEFAULT false NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_scanned_at timestamp with time zone DEFAULT now() NOT NULL,
    indexed_by_user_id bigint,
    file_status character varying(30) DEFAULT 'VISIBLE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_case_attachment_file_status CHECK (((file_status)::text = ANY (ARRAY[('VISIBLE'::character varying)::text, ('MISSING'::character varying)::text, ('TRASHED'::character varying)::text, ('PERMISSION_ERROR'::character varying)::text, ('CACHED_ONLY'::character varying)::text])))
);


--
-- Name: case_attachment_index_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_attachment_index_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_attachment_index_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_attachment_index_id_seq OWNED BY public.case_attachment_index.id;


--
-- Name: case_classifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_classifications (
    id bigint NOT NULL,
    display_label character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_classifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_classifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_classifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_classifications_id_seq OWNED BY public.case_classifications.id;


--
-- Name: case_courts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_courts (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    court_id bigint,
    court_order integer DEFAULT 1 NOT NULL,
    raw_court_text text,
    court_branch text,
    charge_filed text,
    criminal_case_number text,
    information_count integer,
    date_filed_in_court date,
    actual_filing_date date,
    court_status text,
    court_remarks text,
    needs_review boolean DEFAULT true NOT NULL,
    review_reason text,
    source text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    date_filed_in_court_raw text,
    case_event_id bigint,
    information_count_raw text
);


--
-- Name: COLUMN case_courts.date_filed_in_court_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_courts.date_filed_in_court_raw IS 'Original cleaned legacy Date Filed in Court value per court line for exact legacy export reconstruction, including invalid/unparseable legacy text.';


--
-- Name: COLUMN case_courts.information_count_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_courts.information_count_raw IS 'Raw legacy information count text before numeric parsing.';


--
-- Name: case_courts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_courts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_courts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_event_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_event_types (
    id bigint NOT NULL,
    code text NOT NULL,
    display_label text NOT NULL,
    category text DEFAULT 'GENERAL'::text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_system boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE case_event_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_event_types IS 'MVP lookup table for case timeline/event types. Keep event type codes stable because UI and transform scripts use them.';


--
-- Name: case_event_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_event_types ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_event_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_events (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    event_type_id bigint NOT NULL,
    event_date date,
    event_time time without time zone,
    event_order integer DEFAULT 0 NOT NULL,
    title text NOT NULL,
    description text,
    status_id bigint,
    prosecutor_id bigint,
    staff_id bigint,
    court_id bigint,
    details_jsonb jsonb DEFAULT '{}'::jsonb NOT NULL,
    source text DEFAULT 'SYSTEM'::text NOT NULL,
    source_table text,
    source_id bigint,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_line_order integer,
    legacy_raw_text text,
    needs_review boolean DEFAULT false NOT NULL,
    review_reason text,
    is_voided boolean DEFAULT false NOT NULL,
    void_reason text,
    voided_at timestamp with time zone,
    voided_by_user_id bigint,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_case_events_void_reason CHECK ((((is_voided = false) AND (voided_at IS NULL)) OR (is_voided = true)))
);


--
-- Name: TABLE case_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_events IS 'Central MVP timeline/activity table for cases. UI should CRUD case_events through functions/API; specialized tables can be updated by the backend/function when needed.';


--
-- Name: case_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_legacy_attributes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_legacy_attributes (
    id integer NOT NULL,
    case_id integer NOT NULL,
    case_classification_text text,
    minor_flag_text text,
    senior_text text,
    pwd_text text,
    source text DEFAULT 'LEGACY_MIGRATION'::character varying NOT NULL,
    source_detail text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_raw_value text,
    notes text,
    created_by_user_id integer,
    updated_by_user_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE case_legacy_attributes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_legacy_attributes IS 'Case-level legacy/migration attributes needed for exact legacy reconstruction without querying staging tables.';


--
-- Name: case_legacy_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_legacy_attributes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_legacy_attributes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_motions (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    motion_name text NOT NULL,
    date_received date,
    filed_by text,
    motion_status text,
    remarks text,
    source text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_raw_json jsonb,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    case_event_id bigint,
    motion_order integer,
    handling_prosecutor_text text,
    date_received_raw text,
    filed_by_raw text,
    motion_status_raw text,
    date_resolved date,
    date_resolved_raw text,
    date_approved date,
    date_approved_raw text,
    remarks_raw text
);


--
-- Name: COLUMN case_motions.motion_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_motions.motion_order IS 'Line/order of the motion within the legacy row or event group.';


--
-- Name: COLUMN case_motions.handling_prosecutor_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_motions.handling_prosecutor_text IS 'Legacy/raw handling prosecutor text for the motion, if provided.';


--
-- Name: COLUMN case_motions.date_received_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_motions.date_received_raw IS 'Raw cleaned legacy motion Date Received text.';


--
-- Name: COLUMN case_motions.date_resolved; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_motions.date_resolved IS 'Parsed motion Date Resolved. Kept as a proper column because this is a regular motion detail.';


--
-- Name: COLUMN case_motions.date_resolved_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_motions.date_resolved_raw IS 'Raw cleaned legacy motion Date Resolved text.';


--
-- Name: COLUMN case_motions.date_approved; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_motions.date_approved IS 'Parsed motion Date Approved. Kept as a proper column because this is a regular motion detail.';


--
-- Name: COLUMN case_motions.date_approved_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_motions.date_approved_raw IS 'Raw cleaned legacy motion Date Approved text.';


--
-- Name: case_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_motions_id_seq OWNED BY public.case_motions.id;


--
-- Name: case_participant_attributes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_participant_attributes (
    id integer NOT NULL,
    case_participant_id integer NOT NULL,
    age_text text,
    age_years integer,
    age_basis_date date,
    age_source text DEFAULT 'UNKNOWN'::character varying NOT NULL,
    gender_text text,
    gender_normalized text,
    minor_text text,
    is_minor_at_case boolean,
    senior_text text,
    is_senior_at_case boolean,
    pwd_text text,
    is_pwd_at_case boolean,
    resident_of_gentri_text text,
    is_resident_of_gentri boolean,
    source text DEFAULT 'MANUAL_ENTRY'::character varying NOT NULL,
    source_detail text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_raw_value text,
    notes text,
    created_by_user_id integer,
    updated_by_user_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT case_participant_attributes_age_years_check CHECK (((age_years IS NULL) OR ((age_years >= 0) AND (age_years <= 150)))),
    CONSTRAINT chk_case_participant_attributes_age_source CHECK ((age_source = ANY (ARRAY[('UNKNOWN'::character varying)::text, ('LEGACY_TEXT'::character varying)::text, ('MANUAL_ENTRY'::character varying)::text, ('COMPUTED_FROM_BIRTHDATE'::character varying)::text, ('MANUAL_OVERRIDE'::character varying)::text, ('SYSTEM_DERIVED'::character varying)::text]))),
    CONSTRAINT chk_case_participant_attributes_gender_normalized CHECK (((gender_normalized IS NULL) OR (gender_normalized = ANY (ARRAY[('MALE'::character varying)::text, ('FEMALE'::character varying)::text, ('OTHER'::character varying)::text, ('UNKNOWN'::character varying)::text]))))
);


--
-- Name: TABLE case_participant_attributes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_participant_attributes IS 'Case-specific participant snapshots. Use this for age/gender/minor/senior/PWD at the time of the case. Blank legacy values are NULL, not false.';


--
-- Name: COLUMN case_participant_attributes.age_basis_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participant_attributes.age_basis_date IS 'Date used to compute or interpret age, usually cases.date_received or incident date.';


--
-- Name: COLUMN case_participant_attributes.is_minor_at_case; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participant_attributes.is_minor_at_case IS 'Case-specific tri-state value: true = YES, false = explicit NO, NULL = blank/unknown.';


--
-- Name: case_participant_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_participant_attributes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_participant_attributes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_participant_private_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_participant_private_details (
    case_participant_id bigint NOT NULL,
    case_id bigint NOT NULL,
    remarks text,
    source text DEFAULT 'MANUAL_ENTRY'::text NOT NULL,
    source_detail text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_raw_text text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE case_participant_private_details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_participant_private_details IS 'Private/sensitive participant details moved from public.case_participants. Protected by can_view_case_details(case_id).';


--
-- Name: COLUMN case_participant_private_details.case_participant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participant_private_details.case_participant_id IS 'Primary key. References public.case_participants(id).';


--
-- Name: COLUMN case_participant_private_details.case_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participant_private_details.case_id IS 'Duplicated access key for efficient RLS by case_id.';


--
-- Name: case_participant_relationships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_participant_relationships (
    id integer NOT NULL,
    case_id integer NOT NULL,
    from_case_participant_id integer NOT NULL,
    to_case_participant_id integer NOT NULL,
    relationship_type text NOT NULL,
    raw_relationship_text text,
    source text DEFAULT 'MANUAL_ENTRY'::character varying NOT NULL,
    source_detail text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    notes text,
    created_by_user_id integer,
    updated_by_user_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_case_participant_relationship_not_self CHECK ((from_case_participant_id <> to_case_participant_id)),
    CONSTRAINT chk_case_participant_relationship_type CHECK ((relationship_type = ANY (ARRAY[('REPRESENTATIVE_OF'::character varying)::text, ('AUTHORIZED_REPRESENTATIVE_OF'::character varying)::text, ('GUARDIAN_OF'::character varying)::text, ('PARENT_OF'::character varying)::text, ('COUNSEL_OF'::character varying)::text, ('WITNESS_FOR'::character varying)::text, ('WITNESS_AGAINST'::character varying)::text, ('ASSISTED_BY'::character varying)::text, ('RELATED_TO'::character varying)::text, ('OTHER'::character varying)::text])))
);


--
-- Name: TABLE case_participant_relationships; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_participant_relationships IS 'Participant-to-participant relationships within the same case: representative, guardian, parent, counsel, witness for/against, etc.';


--
-- Name: COLUMN case_participant_relationships.from_case_participant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participant_relationships.from_case_participant_id IS 'The acting participant, e.g. representative/witness/guardian/counsel.';


--
-- Name: COLUMN case_participant_relationships.to_case_participant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participant_relationships.to_case_participant_id IS 'The participant being represented/assisted/witnessed for or against.';


--
-- Name: case_participant_relationships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_participant_relationships ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_participant_relationships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_participants (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    person_id bigint,
    role_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    participant_order integer,
    organization_id integer,
    participant_kind text,
    display_name_snapshot text
);


--
-- Name: COLUMN case_participants.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participants.person_id IS 'Natural-person participant. Nullable because a case participant may instead be an organization.';


--
-- Name: COLUMN case_participants.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participants.organization_id IS 'Organization/company/agency participant. Exactly one of person_id or organization_id must be set.';


--
-- Name: COLUMN case_participants.participant_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participants.participant_kind IS 'Display/helper kind: PERSON or ORGANIZATION. The actual source of truth is the non-null FK.';


--
-- Name: COLUMN case_participants.display_name_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_participants.display_name_snapshot IS 'Optional display snapshot at time of entry/import. Do not rely on this as the normalized party name source of truth.';


--
-- Name: case_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_participants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_participants_id_seq OWNED BY public.case_participants.id;


--
-- Name: case_petitions_for_review; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_petitions_for_review (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    case_event_id bigint,
    petition_order integer DEFAULT 1 NOT NULL,
    petition_title text DEFAULT 'Petition for Review'::text NOT NULL,
    handling_prosecutor_text text,
    date_received date,
    date_received_raw text,
    filed_by text,
    petition_status text,
    date_resolved date,
    date_resolved_raw text,
    date_approved date,
    date_approved_raw text,
    remarks text,
    source text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_line_order integer,
    legacy_raw_json jsonb,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_petitions_for_review_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_petitions_for_review ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_petitions_for_review_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_private_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_private_details (
    case_id bigint NOT NULL,
    source text,
    remarks text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_raw_json jsonb,
    is_summary_procedure boolean DEFAULT false,
    summary_text text,
    current_status_id bigint,
    current_status_date date,
    current_status_approved_date_raw text,
    current_status_raw text,
    current_status_remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE case_private_details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_private_details IS 'Private/sensitive case details moved from public.cases. Protected by can_view_case_details(case_id).';


--
-- Name: COLUMN case_private_details.case_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.case_id IS 'Primary key and access key. References public.cases(id).';


--
-- Name: COLUMN case_private_details.current_status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.current_status_id IS 'Current/latest case status for UI list/search. Moved from public.cases.';


--
-- Name: COLUMN case_private_details.current_status_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.current_status_date IS 'Parsed date associated with imported current status. Moved from public.cases.';


--
-- Name: COLUMN case_private_details.current_status_approved_date_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.current_status_approved_date_raw IS 'Raw legacy status approved/date text preserved for export reconstruction.';


--
-- Name: COLUMN case_private_details.current_status_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.current_status_raw IS 'Raw legacy status text before normalization.';


--
-- Name: COLUMN case_private_details.current_status_remarks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.current_status_remarks IS 'Raw legacy status remarks text.';


--
-- Name: case_status_colors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_status_colors (
    id bigint NOT NULL,
    status_id bigint NOT NULL,
    color_key text DEFAULT 'slate'::text NOT NULL,
    background_hex text DEFAULT '#F1F5F9'::text NOT NULL,
    text_hex text DEFAULT '#334155'::text NOT NULL,
    border_hex text DEFAULT '#CBD5E1'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_status_colors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_status_colors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_status_colors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_status_colors_id_seq OWNED BY public.case_status_colors.id;


--
-- Name: case_status_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_status_history (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    from_status_id bigint,
    to_status_id bigint NOT NULL,
    changed_by_user_id bigint NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    remarks text,
    status_date date,
    legacy_status_approved_date_raw text,
    legacy_status_date_raw text,
    case_event_id bigint
);


--
-- Name: COLUMN case_status_history.legacy_status_approved_date_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_status_history.legacy_status_approved_date_raw IS 'Original cleaned legacy Status Approved Date value for exact legacy export reconstruction.';


--
-- Name: COLUMN case_status_history.legacy_status_date_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_status_history.legacy_status_date_raw IS 'Original cleaned legacy Status Date value for exact legacy export reconstruction, including invalid/unparseable legacy text.';


--
-- Name: case_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_status_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_status_history_id_seq OWNED BY public.case_status_history.id;


--
-- Name: case_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_statuses (
    id bigint NOT NULL,
    code text NOT NULL,
    display_label text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_final boolean DEFAULT false NOT NULL,
    is_milestone boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_statuses_id_seq OWNED BY public.case_statuses.id;


--
-- Name: case_violations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_violations (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    violation_id bigint NOT NULL,
    violation_order integer,
    raw_violation_text text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_violations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_violations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_violations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_witness_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_witness_details (
    id integer NOT NULL,
    case_participant_id integer NOT NULL,
    witness_side text DEFAULT 'UNKNOWN'::character varying NOT NULL,
    testimony_type text,
    witness_description text,
    raw_witness_text text,
    source text DEFAULT 'MANUAL_ENTRY'::character varying NOT NULL,
    source_detail text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    notes text,
    created_by_user_id integer,
    updated_by_user_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_case_witness_details_side CHECK ((witness_side = ANY (ARRAY[('PROSECUTION'::character varying)::text, ('DEFENSE'::character varying)::text, ('COMPLAINANT_SIDE'::character varying)::text, ('RESPONDENT_SIDE'::character varying)::text, ('NEUTRAL'::character varying)::text, ('CASE_GENERAL'::character varying)::text, ('UNKNOWN'::character varying)::text]))),
    CONSTRAINT chk_case_witness_details_testimony_type CHECK (((testimony_type IS NULL) OR (testimony_type = ANY (ARRAY[('EYEWITNESS'::character varying)::text, ('ARRESTING_OFFICER'::character varying)::text, ('INVESTIGATOR'::character varying)::text, ('MEDICO_LEGAL'::character varying)::text, ('DOCUMENT_CUSTODIAN'::character varying)::text, ('EXPERT'::character varying)::text, ('CHARACTER_WITNESS'::character varying)::text, ('OTHER'::character varying)::text]))))
);


--
-- Name: TABLE case_witness_details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_witness_details IS 'Witness-specific metadata for participants with WITNESS role. Use relationships for witness-for/witness-against a specific party.';


--
-- Name: case_witness_details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_witness_details ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_witness_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cases (
    id bigint NOT NULL,
    docket_type_id bigint NOT NULL,
    docket_year integer NOT NULL,
    docket_number integer NOT NULL,
    date_received date NOT NULL,
    created_by_user_id bigint NOT NULL,
    updated_by_user_id bigint,
    is_archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    region_code text,
    docket_month_code text,
    case_classification_id bigint
);


--
-- Name: cases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cases_id_seq OWNED BY public.cases.id;


--
-- Name: clearance_phonetic_name_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clearance_phonetic_name_tokens (
    id bigint NOT NULL,
    person_id integer NOT NULL,
    source_table text NOT NULL,
    source_column text NOT NULL,
    source_value text NOT NULL,
    token text NOT NULL,
    token_order integer NOT NULL,
    token_len integer NOT NULL,
    phonetic_primary text,
    phonetic_alt text,
    phonetic_codes text[] NOT NULL,
    refreshed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: clearance_phonetic_name_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.clearance_phonetic_name_tokens ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.clearance_phonetic_name_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: clearance_possible_name_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clearance_possible_name_tokens (
    id bigint NOT NULL,
    person_id integer NOT NULL,
    source_table text NOT NULL,
    source_column text NOT NULL,
    source_value text NOT NULL,
    token text NOT NULL,
    token_order integer NOT NULL,
    token_len integer NOT NULL,
    first_char text NOT NULL,
    first2 text NOT NULL,
    first3 text NOT NULL,
    last2 text NOT NULL,
    last3 text NOT NULL,
    ck_key text NOT NULL,
    bv_key text NOT NULL,
    phf_key text NOT NULL,
    sz_key text NOT NULL,
    skeleton text NOT NULL,
    refreshed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: clearance_possible_name_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.clearance_possible_name_tokens ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.clearance_possible_name_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: courts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courts (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    court_type text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: courts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.courts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: courts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.courts_id_seq OWNED BY public.courts.id;


--
-- Name: docket_number_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.docket_number_history (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    docket_type_id bigint NOT NULL,
    docket_year integer NOT NULL,
    docket_number integer NOT NULL,
    docket_display_number character varying(100) NOT NULL,
    event_type character varying(20) NOT NULL,
    changed_by_user_id bigint NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    reason text
);


--
-- Name: docket_number_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.docket_number_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: docket_number_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.docket_number_history_id_seq OWNED BY public.docket_number_history.id;


--
-- Name: docket_sequence_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.docket_sequence_counters (
    id bigint NOT NULL,
    docket_type_id bigint NOT NULL,
    docket_year integer NOT NULL,
    next_number integer DEFAULT 1 NOT NULL,
    last_issued_number integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: docket_sequence_counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.docket_sequence_counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: docket_sequence_counters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.docket_sequence_counters_id_seq OWNED BY public.docket_sequence_counters.id;


--
-- Name: docket_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.docket_types (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    prefix character varying(20) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: docket_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.docket_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: docket_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.docket_types_id_seq OWNED BY public.docket_types.id;


--
-- Name: migration_review_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migration_review_items (
    id bigint NOT NULL,
    case_id bigint,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    staging_row_id bigint,
    issue_type text NOT NULL,
    severity text DEFAULT 'WARNING'::text NOT NULL,
    raw_value text,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    resolved_by_user_id bigint
);


--
-- Name: migration_review_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.migration_review_items ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.migration_review_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    created_by_user_id bigint NOT NULL,
    note_text text NOT NULL,
    is_private boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notes_id_seq OWNED BY public.notes.id;


--
-- Name: organization_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_aliases (
    id integer NOT NULL,
    organization_id integer NOT NULL,
    alias_name text NOT NULL,
    source text DEFAULT 'MANUAL_ENTRY'::character varying NOT NULL,
    source_detail text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE organization_aliases; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.organization_aliases IS 'Alternative names/acronyms/legacy spellings for organizations.';


--
-- Name: organization_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.organization_aliases ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.organization_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id integer NOT NULL,
    organization_name text NOT NULL,
    organization_type text DEFAULT 'ORGANIZATION'::character varying NOT NULL,
    registration_number text,
    tax_identification_number text,
    contact_person text,
    contact_number text,
    email text,
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    source text DEFAULT 'MANUAL_ENTRY'::character varying NOT NULL,
    source_detail text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_raw_text text,
    created_by_user_id integer,
    updated_by_user_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_organizations_type CHECK ((organization_type = ANY (ARRAY[('ORGANIZATION'::character varying)::text, ('COMPANY'::character varying)::text, ('CORPORATION'::character varying)::text, ('GOVERNMENT_OFFICE'::character varying)::text, ('AGENCY'::character varying)::text, ('BARANGAY'::character varying)::text, ('CITY_GOVERNMENT'::character varying)::text, ('SCHOOL'::character varying)::text, ('BANK'::character varying)::text, ('LENDING_COMPANY'::character varying)::text, ('OTHER'::character varying)::text])))
);


--
-- Name: TABLE organizations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.organizations IS 'First-class non-natural-person parties such as companies, government offices, agencies, barangays, banks, and institutions.';


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.organizations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: participant_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.participant_roles (
    id bigint NOT NULL,
    code text NOT NULL,
    display_label text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: participant_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.participant_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: participant_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.participant_roles_id_seq OWNED BY public.participant_roles.id;


--
-- Name: person_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.person_addresses (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    address_id bigint NOT NULL,
    address_type_id bigint NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    start_date date,
    end_date date,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: person_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.person_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.person_addresses_id_seq OWNED BY public.person_addresses.id;


--
-- Name: person_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.person_aliases (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    alias_name text NOT NULL,
    alias_type character varying(30) DEFAULT 'AKA'::character varying NOT NULL,
    source text DEFAULT 'LEGACY_EXCEL'::character varying NOT NULL,
    source_detail text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_person_alias_type CHECK (((alias_type)::text = ANY (ARRAY[('AKA'::character varying)::text, ('ALIAS'::character varying)::text, ('NICKNAME'::character varying)::text, ('LEGACY_TEXT'::character varying)::text])))
);


--
-- Name: person_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.person_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.person_aliases_id_seq OWNED BY public.person_aliases.id;


--
-- Name: persons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persons (
    id bigint NOT NULL,
    first_name text,
    middle_name text,
    last_name text,
    suffix text,
    full_name text NOT NULL,
    gender text,
    birth_date date,
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    person_descriptor text,
    age text,
    is_minor boolean,
    is_senior boolean,
    is_pwd boolean
);


--
-- Name: COLUMN persons.age; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.persons.age IS 'Nullable helper/profile age text only. Do not use as the source of truth for age in a specific case. Use case_participant_attributes.age_text / age_years.';


--
-- Name: COLUMN persons.is_minor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.persons.is_minor IS 'Nullable helper/profile flag only. Do not use as the source of truth for minor status in a specific case. Use case_participant_attributes.is_minor_at_case.';


--
-- Name: COLUMN persons.is_senior; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.persons.is_senior IS 'Nullable helper/profile flag only. Do not use as the source of truth for senior status in a specific case. Use case_participant_attributes.is_senior_at_case.';


--
-- Name: COLUMN persons.is_pwd; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.persons.is_pwd IS 'Nullable helper/profile flag only. Do not use as the source of truth for PWD status in a specific case. Use case_participant_attributes.is_pwd_at_case.';


--
-- Name: persons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persons_id_seq OWNED BY public.persons.id;


--
-- Name: positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.positions (
    id bigint NOT NULL,
    code text NOT NULL,
    title character varying(100) NOT NULL,
    group_type character varying(20) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_positions_group_type CHECK (((group_type)::text = ANY (ARRAY[('PROSECUTOR'::character varying)::text, ('STAFF'::character varying)::text])))
);


--
-- Name: positions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.positions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.positions_id_seq OWNED BY public.positions.id;


--
-- Name: prosecutor_staff_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prosecutor_staff_assignments (
    id bigint NOT NULL,
    prosecutor_id bigint NOT NULL,
    staff_id bigint NOT NULL,
    assigned_by_user_id bigint NOT NULL,
    start_date date DEFAULT CURRENT_DATE NOT NULL,
    end_date date,
    is_active boolean DEFAULT true NOT NULL,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: prosecutor_staff_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.prosecutor_staff_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: prosecutor_staff_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.prosecutor_staff_assignments_id_seq OWNED BY public.prosecutor_staff_assignments.id;


--
-- Name: prosecutors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prosecutors (
    id bigint NOT NULL,
    first_name text NOT NULL,
    middle_name text,
    last_name text NOT NULL,
    suffix text,
    full_name text NOT NULL,
    short_name text,
    position_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: prosecutors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.prosecutors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: prosecutors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.prosecutors_id_seq OWNED BY public.prosecutors.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    code text NOT NULL,
    display_label text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: staff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff (
    id bigint NOT NULL,
    first_name text NOT NULL,
    middle_name text,
    last_name text NOT NULL,
    suffix text,
    full_name text NOT NULL,
    short_name text,
    position_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staff_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_id_seq OWNED BY public.staff.id;


--
-- Name: staging_dc2025_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_dc2025_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_dc2025_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_dc2025_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_dc2025_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inq2022_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inq2022_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_inq2022_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2022_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inq2022_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inq2023_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inq2023_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_inq2023_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2023_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inq2023_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inq2024_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inq2024_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_inq2024_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2024_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inq2024_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inq2025_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inq2025_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_inq2025_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2025_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inq2025_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inv2022b_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inv2022b_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_inv2022b_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2022b_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inv2022b_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inv2023_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inv2023_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_inv2023_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2023_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inv2023_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inv2024_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inv2024_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_inv2024_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2024_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inv2024_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_inv2025_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_inv2025_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text DEFAULT 'INV25(1).xlsx'::text NOT NULL,
    source_sheet text DEFAULT 'INV 2025'::text NOT NULL,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE staging_inv2025_normalized_rows; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.staging_inv2025_normalized_rows IS 'Cleaned staging rows for INV25 case-events migration. Preserve multiline order for persons, violations, courts, and motions.';


--
-- Name: staging_inv2025_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2025_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_inv2025_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging_pe2024_normalized_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_pe2024_normalized_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text DEFAULT 'VALID_DOCKET'::text NOT NULL,
    source_file text,
    source_sheet text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    violation_raw text,
    case_classification_raw text,
    case_remarks_raw text,
    summary_raw text,
    summary_remarks_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    complainant_senior_raw text,
    complainant_pwd_raw text,
    complainant_resident_gentri_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    respondent_senior_raw text,
    respondent_pwd_raw text,
    respondent_resident_gentri_raw text,
    date_received_raw text,
    date_raffled_raw text,
    prosecutor_raw text,
    status_approved_date_raw text,
    status_raw text,
    status_remarks_raw text,
    date_filed_in_court_raw text,
    court_raw text,
    court_branch_raw text,
    charge_raw text,
    information_count_raw text,
    criminal_case_number_raw text,
    court_status_raw text,
    court_remarks_raw text,
    motion_raw text,
    motion_handling_prosecutor_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_date_resolved_raw text,
    motion_date_approved_raw text,
    motion_remarks_raw text,
    petition_raw text,
    petition_date_received_raw text,
    petition_filed_by_raw text,
    petition_status_raw text,
    petition_date_resolved_raw text,
    petition_date_approved_raw text,
    petition_remarks_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staging_pe2024_normalized_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.staging_pe2024_normalized_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staging_pe2024_normalized_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    user_id bigint NOT NULL,
    role_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    prosecutor_id bigint,
    staff_id bigint,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    auth_user_id uuid,
    CONSTRAINT users_only_one_office_identity CHECK ((NOT ((prosecutor_id IS NOT NULL) AND (staff_id IS NOT NULL))))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_case_participants_long_term; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_participants_long_term WITH (security_invoker='false') AS
 WITH access AS (
         SELECT cp_1.id AS case_participant_id,
            public.can_view_case_details(cp_1.case_id) AS can_details
           FROM public.case_participants cp_1
          WHERE public.is_authenticated_app_user()
        )
 SELECT cp.id AS case_participant_id,
    cp.case_id,
    pr.code AS role_code,
    pr.display_label AS role_label,
    cp.participant_order,
    cp.participant_kind,
    cp.person_id,
    cp.organization_id,
        CASE
            WHEN access.can_details THEN COALESCE(p.full_name, o.organization_name, cp.display_name_snapshot)
            ELSE cp.display_name_snapshot
        END AS display_name,
        CASE
            WHEN access.can_details THEN p.full_name
            ELSE NULL::text
        END AS person_name,
        CASE
            WHEN access.can_details THEN o.organization_name
            ELSE NULL::text
        END AS organization_name,
        CASE
            WHEN access.can_details THEN o.organization_type
            ELSE NULL::text
        END AS organization_type,
        CASE
            WHEN access.can_details THEN cpa.age_text
            ELSE NULL::text
        END AS age_text,
        CASE
            WHEN access.can_details THEN cpa.age_years
            ELSE NULL::integer
        END AS age_years,
        CASE
            WHEN access.can_details THEN cpa.gender_text
            ELSE NULL::text
        END AS gender_text,
        CASE
            WHEN access.can_details THEN cpa.gender_normalized
            ELSE NULL::text
        END AS gender_normalized,
        CASE
            WHEN access.can_details THEN cpa.minor_text
            ELSE NULL::text
        END AS minor_text,
        CASE
            WHEN access.can_details THEN cpa.is_minor_at_case
            ELSE NULL::boolean
        END AS is_minor_at_case,
        CASE
            WHEN access.can_details THEN cpa.senior_text
            ELSE NULL::text
        END AS senior_text,
        CASE
            WHEN access.can_details THEN cpa.is_senior_at_case
            ELSE NULL::boolean
        END AS is_senior_at_case,
        CASE
            WHEN access.can_details THEN cpa.pwd_text
            ELSE NULL::text
        END AS pwd_text,
        CASE
            WHEN access.can_details THEN cpa.is_pwd_at_case
            ELSE NULL::boolean
        END AS is_pwd_at_case,
        CASE
            WHEN access.can_details THEN cppd.remarks
            ELSE NULL::text
        END AS remarks,
        CASE
            WHEN access.can_details THEN cppd.source
            ELSE NULL::text
        END AS source,
        CASE
            WHEN access.can_details THEN cppd.source_detail
            ELSE NULL::text
        END AS source_detail,
        CASE
            WHEN access.can_details THEN cppd.legacy_source_file
            ELSE NULL::text
        END AS legacy_source_file,
        CASE
            WHEN access.can_details THEN cppd.legacy_source_sheet
            ELSE NULL::text
        END AS legacy_source_sheet,
        CASE
            WHEN access.can_details THEN cppd.legacy_row_number
            ELSE NULL::integer
        END AS legacy_row_number,
        CASE
            WHEN access.can_details THEN cppd.legacy_raw_text
            ELSE NULL::text
        END AS legacy_raw_text
   FROM ((((((public.case_participants cp
     JOIN access ON ((access.case_participant_id = cp.id)))
     JOIN public.participant_roles pr ON ((pr.id = cp.role_id)))
     LEFT JOIN public.persons p ON ((p.id = cp.person_id)))
     LEFT JOIN public.organizations o ON ((o.id = cp.organization_id)))
     LEFT JOIN public.case_participant_attributes cpa ON ((cpa.case_participant_id = cp.id)))
     LEFT JOIN public.case_participant_private_details cppd ON ((cppd.case_participant_id = cp.id)));


--
-- Name: v_case_timeline; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_timeline WITH (security_invoker='false') AS
 SELECT ce.id AS case_event_id,
    ce.case_id,
    dt.prefix AS docket_type,
    c.docket_year,
    c.docket_month_code,
    c.docket_number,
    concat_ws('-'::text, c.region_code, dt.prefix, ("right"((c.docket_year)::text, 2) || COALESCE(c.docket_month_code, ''::text)), lpad((c.docket_number)::text, 6, '0'::text)) AS docket_display_number,
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
    ce.updated_at
   FROM (((((((public.case_events ce
     JOIN public.cases c ON ((c.id = ce.case_id)))
     JOIN public.docket_types dt ON ((dt.id = c.docket_type_id)))
     JOIN public.case_event_types cet ON ((cet.id = ce.event_type_id)))
     LEFT JOIN public.case_statuses cs ON ((cs.id = ce.status_id)))
     LEFT JOIN public.prosecutors p ON ((p.id = ce.prosecutor_id)))
     LEFT JOIN public.staff st ON ((st.id = ce.staff_id)))
     LEFT JOIN public.courts co ON ((co.id = ce.court_id)))
  WHERE public.can_view_case_details(ce.case_id);


--
-- Name: violations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.violations (
    id bigint NOT NULL,
    reference_code text,
    title text NOT NULL,
    short_label text,
    description text,
    law_reference text,
    is_active boolean DEFAULT true NOT NULL,
    created_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    canonical_title text
);


--
-- Name: v_cases_display; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cases_display WITH (security_invoker='false') AS
 WITH ctx AS (
         SELECT public.is_authenticated_app_user() AS is_app_user,
            public.has_any_app_role(ARRAY['DEVELOPER'::text, 'CHIEF'::text, 'ADMIN'::text]) AS can_view_all_details,
            public.has_app_role('PROSECUTOR'::text) AS is_prosecutor,
            public.has_app_role('STAFF'::text) AS is_staff,
            public.current_app_prosecutor_id() AS my_prosecutor_id,
            public.current_app_staff_id() AS my_staff_id
        ), latest_assignment AS (
         SELECT DISTINCT ON (ca_1.case_id) ca_1.case_id,
            ca_1.prosecutor_id,
            ca_1.staff_id,
            ca_1.assigned_at
           FROM public.case_assignments ca_1
          WHERE (ca_1.unassigned_at IS NULL)
          ORDER BY ca_1.case_id, ca_1.assigned_at DESC NULLS LAST, ca_1.id DESC
        ), case_access AS (
         SELECT c_1.id AS case_id,
            (ctx.can_view_all_details OR (ctx.is_prosecutor AND (la_1.prosecutor_id = ctx.my_prosecutor_id)) OR (ctx.is_staff AND ((la_1.staff_id = ctx.my_staff_id) OR (EXISTS ( SELECT 1
                   FROM public.prosecutor_staff_assignments psa
                  WHERE ((psa.prosecutor_id = la_1.prosecutor_id) AND (psa.staff_id = ctx.my_staff_id) AND (psa.is_active = true) AND (psa.start_date <= CURRENT_DATE) AND ((psa.end_date IS NULL) OR (psa.end_date >= CURRENT_DATE)))))))) AS can_details
           FROM ((public.cases c_1
             CROSS JOIN ctx)
             LEFT JOIN latest_assignment la_1 ON ((la_1.case_id = c_1.id)))
          WHERE (ctx.is_app_user = true)
        ), violation_summary AS (
         SELECT cv.case_id,
            string_agg(v.title, ', '::text ORDER BY cv.violation_order, v.title) AS violations
           FROM (public.case_violations cv
             JOIN public.violations v ON ((v.id = cv.violation_id)))
          GROUP BY cv.case_id
        )
 SELECT c.id,
    c.docket_type_id,
    c.docket_year,
    c.docket_number,
    c.date_received,
        CASE
            WHEN ca.can_details THEN cpd.source
            ELSE NULL::text
        END AS source,
        CASE
            WHEN ca.can_details THEN cpd.remarks
            ELSE NULL::text
        END AS remarks,
    NULL::text AS gdrive_folder_id,
    NULL::text AS gdrive_folder_link,
    NULL::text AS gdrive_folder_name,
    NULL::text AS gdrive_folder_status,
    NULL::timestamp with time zone AS gdrive_folder_last_scanned_at,
    c.created_by_user_id,
    c.updated_by_user_id,
    c.is_archived,
    c.created_at,
    c.updated_at,
    c.region_code,
    c.docket_month_code,
        CASE
            WHEN ca.can_details THEN cpd.legacy_source_file
            ELSE NULL::text
        END AS legacy_source_file,
        CASE
            WHEN ca.can_details THEN cpd.legacy_source_sheet
            ELSE NULL::text
        END AS legacy_source_sheet,
        CASE
            WHEN ca.can_details THEN cpd.legacy_row_number
            ELSE NULL::integer
        END AS legacy_row_number,
        CASE
            WHEN ca.can_details THEN cpd.legacy_raw_json
            ELSE NULL::jsonb
        END AS legacy_raw_json,
        CASE
            WHEN ca.can_details THEN cpd.is_summary_procedure
            ELSE NULL::boolean
        END AS is_summary_procedure,
        CASE
            WHEN ca.can_details THEN cpd.summary_text
            ELSE NULL::text
        END AS summary_text,
    (((((((dt.prefix)::text || '-'::text) || (c.docket_year)::text) || '-'::text) || COALESCE(c.docket_month_code, ''::text)) || '-'::text) || lpad((c.docket_number)::text, 6, '0'::text)) AS docket_display_number,
    dt.prefix AS docket_type_prefix,
    dt.name AS docket_type_name,
        CASE
            WHEN ca.can_details THEN cs.code
            ELSE NULL::text
        END AS current_status_code,
        CASE
            WHEN ca.can_details THEN cs.display_label
            ELSE NULL::text
        END AS current_status_label,
        CASE
            WHEN ca.can_details THEN cpd.current_status_date
            ELSE NULL::date
        END AS current_status_date,
    la.prosecutor_id AS current_prosecutor_id,
    p.short_name AS prosecutor_short_name,
    p.full_name AS prosecutor_full_name,
    la.staff_id AS current_staff_id,
    st.short_name AS staff_short_name,
    st.full_name AS staff_full_name,
    la.assigned_at AS current_assigned_at,
    NULL::text AS court_codes,
    NULL::text AS criminal_case_numbers,
    NULL::boolean AS court_needs_review,
    vs.violations,
    c.case_classification_id,
    cc.display_label AS case_classification_label,
    cc.description AS case_classification_description
   FROM (((((((((public.cases c
     JOIN public.docket_types dt ON ((dt.id = c.docket_type_id)))
     JOIN case_access ca ON ((ca.case_id = c.id)))
     LEFT JOIN public.case_private_details cpd ON ((cpd.case_id = c.id)))
     LEFT JOIN public.case_statuses cs ON ((cs.id = cpd.current_status_id)))
     LEFT JOIN latest_assignment la ON ((la.case_id = c.id)))
     LEFT JOIN public.prosecutors p ON ((p.id = la.prosecutor_id)))
     LEFT JOIN public.staff st ON ((st.id = la.staff_id)))
     LEFT JOIN violation_summary vs ON ((vs.case_id = c.id)))
     LEFT JOIN public.case_classifications cc ON ((cc.id = c.case_classification_id)));


--
-- Name: violations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.violations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: violations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.violations_id_seq OWNED BY public.violations.id;


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea
)
PARTITION BY RANGE (inserted_at);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    action_filter text DEFAULT '*'::text,
    selected_columns text[],
    CONSTRAINT subscription_action_filter_check CHECK ((action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb,
    metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: address_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_types ALTER COLUMN id SET DEFAULT nextval('public.address_types_id_seq'::regclass);


--
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN id SET DEFAULT nextval('public.audit_logs_id_seq'::regclass);


--
-- Name: case_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_addresses ALTER COLUMN id SET DEFAULT nextval('public.case_addresses_id_seq'::regclass);


--
-- Name: case_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments ALTER COLUMN id SET DEFAULT nextval('public.case_assignments_id_seq'::regclass);


--
-- Name: case_attachment_index id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attachment_index ALTER COLUMN id SET DEFAULT nextval('public.case_attachment_index_id_seq'::regclass);


--
-- Name: case_classifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_classifications ALTER COLUMN id SET DEFAULT nextval('public.case_classifications_id_seq'::regclass);


--
-- Name: case_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions ALTER COLUMN id SET DEFAULT nextval('public.case_motions_id_seq'::regclass);


--
-- Name: case_participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participants ALTER COLUMN id SET DEFAULT nextval('public.case_participants_id_seq'::regclass);


--
-- Name: case_status_colors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_colors ALTER COLUMN id SET DEFAULT nextval('public.case_status_colors_id_seq'::regclass);


--
-- Name: case_status_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_history ALTER COLUMN id SET DEFAULT nextval('public.case_status_history_id_seq'::regclass);


--
-- Name: case_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_statuses ALTER COLUMN id SET DEFAULT nextval('public.case_statuses_id_seq'::regclass);


--
-- Name: cases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases ALTER COLUMN id SET DEFAULT nextval('public.cases_id_seq'::regclass);


--
-- Name: courts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts ALTER COLUMN id SET DEFAULT nextval('public.courts_id_seq'::regclass);


--
-- Name: docket_number_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_number_history ALTER COLUMN id SET DEFAULT nextval('public.docket_number_history_id_seq'::regclass);


--
-- Name: docket_sequence_counters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_sequence_counters ALTER COLUMN id SET DEFAULT nextval('public.docket_sequence_counters_id_seq'::regclass);


--
-- Name: docket_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_types ALTER COLUMN id SET DEFAULT nextval('public.docket_types_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: participant_roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_roles ALTER COLUMN id SET DEFAULT nextval('public.participant_roles_id_seq'::regclass);


--
-- Name: person_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_addresses ALTER COLUMN id SET DEFAULT nextval('public.person_addresses_id_seq'::regclass);


--
-- Name: person_aliases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_aliases ALTER COLUMN id SET DEFAULT nextval('public.person_aliases_id_seq'::regclass);


--
-- Name: persons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persons ALTER COLUMN id SET DEFAULT nextval('public.persons_id_seq'::regclass);


--
-- Name: positions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.positions ALTER COLUMN id SET DEFAULT nextval('public.positions_id_seq'::regclass);


--
-- Name: prosecutor_staff_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutor_staff_assignments ALTER COLUMN id SET DEFAULT nextval('public.prosecutor_staff_assignments_id_seq'::regclass);


--
-- Name: prosecutors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutors ALTER COLUMN id SET DEFAULT nextval('public.prosecutors_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: staff id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff ALTER COLUMN id SET DEFAULT nextval('public.staff_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: violations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.violations ALTER COLUMN id SET DEFAULT nextval('public.violations_id_seq'::regclass);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: custom_oauth_providers custom_oauth_providers_identifier_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_identifier_key UNIQUE (identifier);


--
-- Name: custom_oauth_providers custom_oauth_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webauthn_challenges webauthn_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


--
-- Name: address_types address_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_types
    ADD CONSTRAINT address_types_code_key UNIQUE (code);


--
-- Name: address_types address_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_types
    ADD CONSTRAINT address_types_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: case_addresses case_addresses_case_id_address_id_address_type_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_addresses
    ADD CONSTRAINT case_addresses_case_id_address_id_address_type_id_key UNIQUE (case_id, address_id, address_type_id);


--
-- Name: case_addresses case_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_addresses
    ADD CONSTRAINT case_addresses_pkey PRIMARY KEY (id);


--
-- Name: case_assignments case_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_pkey PRIMARY KEY (id);


--
-- Name: case_attachment_index case_attachment_index_case_id_gdrive_file_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attachment_index
    ADD CONSTRAINT case_attachment_index_case_id_gdrive_file_id_key UNIQUE (case_id, gdrive_file_id);


--
-- Name: case_attachment_index case_attachment_index_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attachment_index
    ADD CONSTRAINT case_attachment_index_pkey PRIMARY KEY (id);


--
-- Name: case_classifications case_classifications_display_label_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_classifications
    ADD CONSTRAINT case_classifications_display_label_key UNIQUE (display_label);


--
-- Name: case_classifications case_classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_classifications
    ADD CONSTRAINT case_classifications_pkey PRIMARY KEY (id);


--
-- Name: case_courts case_courts_case_id_court_order_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_courts
    ADD CONSTRAINT case_courts_case_id_court_order_key UNIQUE (case_id, court_order);


--
-- Name: case_courts case_courts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_courts
    ADD CONSTRAINT case_courts_pkey PRIMARY KEY (id);


--
-- Name: case_event_types case_event_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_event_types
    ADD CONSTRAINT case_event_types_code_key UNIQUE (code);


--
-- Name: case_event_types case_event_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_event_types
    ADD CONSTRAINT case_event_types_pkey PRIMARY KEY (id);


--
-- Name: case_events case_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_pkey PRIMARY KEY (id);


--
-- Name: case_legacy_attributes case_legacy_attributes_case_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_legacy_attributes
    ADD CONSTRAINT case_legacy_attributes_case_id_key UNIQUE (case_id);


--
-- Name: case_legacy_attributes case_legacy_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_legacy_attributes
    ADD CONSTRAINT case_legacy_attributes_pkey PRIMARY KEY (id);


--
-- Name: case_motions case_motions_legacy_motion_order_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions
    ADD CONSTRAINT case_motions_legacy_motion_order_key UNIQUE (case_id, source, legacy_source_file, legacy_source_sheet, legacy_row_number, motion_order);


--
-- Name: case_motions case_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions
    ADD CONSTRAINT case_motions_pkey PRIMARY KEY (id);


--
-- Name: case_participant_attributes case_participant_attributes_case_participant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_attributes
    ADD CONSTRAINT case_participant_attributes_case_participant_id_key UNIQUE (case_participant_id);


--
-- Name: case_participant_attributes case_participant_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_attributes
    ADD CONSTRAINT case_participant_attributes_pkey PRIMARY KEY (id);


--
-- Name: case_participant_private_details case_participant_private_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_private_details
    ADD CONSTRAINT case_participant_private_details_pkey PRIMARY KEY (case_participant_id);


--
-- Name: case_participant_relationships case_participant_relationships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_relationships
    ADD CONSTRAINT case_participant_relationships_pkey PRIMARY KEY (id);


--
-- Name: case_participants case_participants_case_id_person_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participants
    ADD CONSTRAINT case_participants_case_id_person_id_role_id_key UNIQUE (case_id, person_id, role_id);


--
-- Name: case_participants case_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participants
    ADD CONSTRAINT case_participants_pkey PRIMARY KEY (id);


--
-- Name: case_petitions_for_review case_petitions_for_review_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_petitions_for_review
    ADD CONSTRAINT case_petitions_for_review_pkey PRIMARY KEY (id);


--
-- Name: case_private_details case_private_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_private_details
    ADD CONSTRAINT case_private_details_pkey PRIMARY KEY (case_id);


--
-- Name: case_status_colors case_status_colors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_colors
    ADD CONSTRAINT case_status_colors_pkey PRIMARY KEY (id);


--
-- Name: case_status_colors case_status_colors_status_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_colors
    ADD CONSTRAINT case_status_colors_status_id_key UNIQUE (status_id);


--
-- Name: case_status_history case_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_history
    ADD CONSTRAINT case_status_history_pkey PRIMARY KEY (id);


--
-- Name: case_statuses case_statuses_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_statuses
    ADD CONSTRAINT case_statuses_code_key UNIQUE (code);


--
-- Name: case_statuses case_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_statuses
    ADD CONSTRAINT case_statuses_pkey PRIMARY KEY (id);


--
-- Name: case_violations case_violations_case_id_violation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_violations
    ADD CONSTRAINT case_violations_case_id_violation_id_key UNIQUE (case_id, violation_id);


--
-- Name: case_violations case_violations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_violations
    ADD CONSTRAINT case_violations_pkey PRIMARY KEY (id);


--
-- Name: case_witness_details case_witness_details_case_participant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_witness_details
    ADD CONSTRAINT case_witness_details_case_participant_id_key UNIQUE (case_participant_id);


--
-- Name: case_witness_details case_witness_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_witness_details
    ADD CONSTRAINT case_witness_details_pkey PRIMARY KEY (id);


--
-- Name: cases cases_docket_type_id_docket_year_docket_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_docket_type_id_docket_year_docket_number_key UNIQUE (docket_type_id, docket_year, docket_number);


--
-- Name: cases cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (id);


--
-- Name: case_participants chk_case_participants_exactly_one_party; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.case_participants
    ADD CONSTRAINT chk_case_participants_exactly_one_party CHECK (((((person_id IS NOT NULL))::integer + ((organization_id IS NOT NULL))::integer) = 1)) NOT VALID;


--
-- Name: case_participants chk_case_participants_kind; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.case_participants
    ADD CONSTRAINT chk_case_participants_kind CHECK (((participant_kind IS NULL) OR (participant_kind = ANY (ARRAY[('PERSON'::character varying)::text, ('ORGANIZATION'::character varying)::text])))) NOT VALID;


--
-- Name: clearance_phonetic_name_tokens clearance_phonetic_name_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clearance_phonetic_name_tokens
    ADD CONSTRAINT clearance_phonetic_name_tokens_pkey PRIMARY KEY (id);


--
-- Name: clearance_possible_name_tokens clearance_possible_name_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clearance_possible_name_tokens
    ADD CONSTRAINT clearance_possible_name_tokens_pkey PRIMARY KEY (id);


--
-- Name: courts courts_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_code_key UNIQUE (code);


--
-- Name: courts courts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_pkey PRIMARY KEY (id);


--
-- Name: docket_number_history docket_number_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_number_history
    ADD CONSTRAINT docket_number_history_pkey PRIMARY KEY (id);


--
-- Name: docket_sequence_counters docket_sequence_counters_docket_type_id_docket_year_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_sequence_counters
    ADD CONSTRAINT docket_sequence_counters_docket_type_id_docket_year_key UNIQUE (docket_type_id, docket_year);


--
-- Name: docket_sequence_counters docket_sequence_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_sequence_counters
    ADD CONSTRAINT docket_sequence_counters_pkey PRIMARY KEY (id);


--
-- Name: docket_types docket_types_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_types
    ADD CONSTRAINT docket_types_name_key UNIQUE (name);


--
-- Name: docket_types docket_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_types
    ADD CONSTRAINT docket_types_pkey PRIMARY KEY (id);


--
-- Name: docket_types docket_types_prefix_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_types
    ADD CONSTRAINT docket_types_prefix_key UNIQUE (prefix);


--
-- Name: migration_review_items migration_review_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migration_review_items
    ADD CONSTRAINT migration_review_items_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: organization_aliases organization_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_aliases
    ADD CONSTRAINT organization_aliases_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: participant_roles participant_roles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_roles
    ADD CONSTRAINT participant_roles_code_key UNIQUE (code);


--
-- Name: participant_roles participant_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_roles
    ADD CONSTRAINT participant_roles_pkey PRIMARY KEY (id);


--
-- Name: person_addresses person_addresses_person_id_address_id_address_type_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_addresses
    ADD CONSTRAINT person_addresses_person_id_address_id_address_type_id_key UNIQUE (person_id, address_id, address_type_id);


--
-- Name: person_addresses person_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_addresses
    ADD CONSTRAINT person_addresses_pkey PRIMARY KEY (id);


--
-- Name: person_aliases person_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_aliases
    ADD CONSTRAINT person_aliases_pkey PRIMARY KEY (id);


--
-- Name: persons persons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_pkey PRIMARY KEY (id);


--
-- Name: positions positions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_code_key UNIQUE (code);


--
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutor_staff_assignments
    ADD CONSTRAINT prosecutor_staff_assignments_pkey PRIMARY KEY (id);


--
-- Name: prosecutors prosecutors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutors
    ADD CONSTRAINT prosecutors_pkey PRIMARY KEY (id);


--
-- Name: roles roles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_code_key UNIQUE (code);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (id);


--
-- Name: staging_dc2025_normalized_rows staging_dc2025_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_dc2025_normalized_rows
    ADD CONSTRAINT staging_dc2025_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inq2022_normalized_rows staging_inq2022_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inq2022_normalized_rows
    ADD CONSTRAINT staging_inq2022_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inq2023_normalized_rows staging_inq2023_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inq2023_normalized_rows
    ADD CONSTRAINT staging_inq2023_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inq2024_normalized_rows staging_inq2024_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inq2024_normalized_rows
    ADD CONSTRAINT staging_inq2024_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inq2025_normalized_rows staging_inq2025_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inq2025_normalized_rows
    ADD CONSTRAINT staging_inq2025_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inv2022b_normalized_rows staging_inv2022b_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inv2022b_normalized_rows
    ADD CONSTRAINT staging_inv2022b_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inv2023_normalized_rows staging_inv2023_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inv2023_normalized_rows
    ADD CONSTRAINT staging_inv2023_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inv2024_normalized_rows staging_inv2024_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inv2024_normalized_rows
    ADD CONSTRAINT staging_inv2024_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inv2025_normalized_rows staging_inv2025_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inv2025_normalized_rows
    ADD CONSTRAINT staging_inv2025_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_pe2024_normalized_rows staging_pe2024_normalized_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_pe2024_normalized_rows
    ADD CONSTRAINT staging_pe2024_normalized_rows_pkey PRIMARY KEY (id);


--
-- Name: staging_inv2025_normalized_rows uq_staging_inv2025_source_row; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staging_inv2025_normalized_rows
    ADD CONSTRAINT uq_staging_inv2025_source_row UNIQUE (source_file, source_sheet, excel_row_number);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: case_petitions_for_review ux_case_petitions_review_legacy; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_petitions_for_review
    ADD CONSTRAINT ux_case_petitions_review_legacy UNIQUE (case_id, source, legacy_source_file, legacy_source_sheet, legacy_row_number, petition_order);


--
-- Name: violations violations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.violations
    ADD CONSTRAINT violations_pkey PRIMARY KEY (id);


--
-- Name: messages messages_payload_exclusive; Type: CHECK CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages
    ADD CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL))) NOT VALID;


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: custom_oauth_providers_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_created_at_idx ON auth.custom_oauth_providers USING btree (created_at);


--
-- Name: custom_oauth_providers_enabled_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_enabled_idx ON auth.custom_oauth_providers USING btree (enabled);


--
-- Name: custom_oauth_providers_identifier_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_identifier_idx ON auth.custom_oauth_providers USING btree (identifier);


--
-- Name: custom_oauth_providers_provider_type_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_provider_type_idx ON auth.custom_oauth_providers USING btree (provider_type);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: idx_users_created_at_desc; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_created_at_desc ON auth.users USING btree (created_at DESC);


--
-- Name: idx_users_email; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_email ON auth.users USING btree (email);


--
-- Name: idx_users_last_sign_in_at_desc; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_last_sign_in_at_desc ON auth.users USING btree (last_sign_in_at DESC);


--
-- Name: idx_users_name; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_name ON auth.users USING btree (((raw_user_meta_data ->> 'name'::text))) WHERE ((raw_user_meta_data ->> 'name'::text) IS NOT NULL);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: webauthn_challenges_expires_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_expires_at_idx ON auth.webauthn_challenges USING btree (expires_at);


--
-- Name: webauthn_challenges_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_user_id_idx ON auth.webauthn_challenges USING btree (user_id);


--
-- Name: webauthn_credentials_credential_id_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX webauthn_credentials_credential_id_key ON auth.webauthn_credentials USING btree (credential_id);


--
-- Name: webauthn_credentials_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_credentials_user_id_idx ON auth.webauthn_credentials USING btree (user_id);


--
-- Name: idx_audit_logs_action_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_action_time ON public.audit_logs USING btree (action, created_at DESC);


--
-- Name: idx_audit_logs_actor_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_actor_time ON public.audit_logs USING btree (actor_user_id, created_at DESC);


--
-- Name: idx_audit_logs_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_entity ON public.audit_logs USING btree (entity_name, entity_id, created_at DESC);


--
-- Name: idx_case_addresses_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_addresses_address ON public.case_addresses USING btree (address_id);


--
-- Name: idx_case_addresses_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_addresses_case ON public.case_addresses USING btree (case_id);


--
-- Name: idx_case_assignments_active_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_active_case ON public.case_assignments USING btree (case_id) WHERE (unassigned_at IS NULL);


--
-- Name: idx_case_assignments_active_prosecutor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_active_prosecutor ON public.case_assignments USING btree (prosecutor_id, case_id) WHERE (unassigned_at IS NULL);


--
-- Name: idx_case_assignments_active_prosecutor_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_active_prosecutor_case ON public.case_assignments USING btree (prosecutor_id, case_id) WHERE (unassigned_at IS NULL);


--
-- Name: idx_case_assignments_active_staff; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_active_staff ON public.case_assignments USING btree (staff_id, case_id) WHERE (unassigned_at IS NULL);


--
-- Name: idx_case_assignments_active_staff_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_active_staff_case ON public.case_assignments USING btree (staff_id, case_id) WHERE (unassigned_at IS NULL);


--
-- Name: idx_case_assignments_case_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_case_event_id ON public.case_assignments USING btree (case_event_id);


--
-- Name: idx_case_assignments_case_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_case_time ON public.case_assignments USING btree (case_id, assigned_at DESC);


--
-- Name: idx_case_assignments_latest_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_latest_active ON public.case_assignments USING btree (case_id, assigned_at DESC, id DESC) WHERE (unassigned_at IS NULL);


--
-- Name: idx_case_assignments_prosecutor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_prosecutor ON public.case_assignments USING btree (prosecutor_id);


--
-- Name: idx_case_assignments_staff; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_staff ON public.case_assignments USING btree (staff_id);


--
-- Name: idx_case_attachment_index_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_attachment_index_case ON public.case_attachment_index USING btree (case_id);


--
-- Name: idx_case_attachment_index_case_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_attachment_index_case_status ON public.case_attachment_index USING btree (case_id, file_status);


--
-- Name: idx_case_attachment_index_gdrive_file; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_attachment_index_gdrive_file ON public.case_attachment_index USING btree (gdrive_file_id);


--
-- Name: idx_case_attachment_index_offline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_attachment_index_offline ON public.case_attachment_index USING btree (case_id, is_available_offline);


--
-- Name: idx_case_attachment_index_scan_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_attachment_index_scan_time ON public.case_attachment_index USING btree (last_scanned_at DESC);


--
-- Name: idx_case_courts_case_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_courts_case_event_id ON public.case_courts USING btree (case_event_id);


--
-- Name: idx_case_courts_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_courts_case_id ON public.case_courts USING btree (case_id);


--
-- Name: idx_case_courts_court_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_courts_court_id ON public.case_courts USING btree (court_id);


--
-- Name: idx_case_courts_criminal_case_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_courts_criminal_case_number ON public.case_courts USING btree (criminal_case_number);


--
-- Name: idx_case_courts_needs_review; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_courts_needs_review ON public.case_courts USING btree (needs_review);


--
-- Name: idx_case_events_case_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_events_case_date ON public.case_events USING btree (case_id, event_date, event_order, id);


--
-- Name: idx_case_events_details_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_events_details_gin ON public.case_events USING gin (details_jsonb);


--
-- Name: idx_case_events_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_events_legacy_row ON public.case_events USING btree (legacy_source_file, legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_events_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_events_type ON public.case_events USING btree (event_type_id);


--
-- Name: idx_case_legacy_attributes_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_legacy_attributes_case_id ON public.case_legacy_attributes USING btree (case_id);


--
-- Name: idx_case_legacy_attributes_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_legacy_attributes_legacy_row ON public.case_legacy_attributes USING btree (legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_motions_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_case ON public.case_motions USING btree (case_id);


--
-- Name: idx_case_motions_case_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_case_event_id ON public.case_motions USING btree (case_event_id);


--
-- Name: idx_case_motions_date_approved; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_date_approved ON public.case_motions USING btree (date_approved DESC);


--
-- Name: idx_case_motions_date_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_date_received ON public.case_motions USING btree (date_received DESC);


--
-- Name: idx_case_motions_date_resolved; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_date_resolved ON public.case_motions USING btree (date_resolved DESC);


--
-- Name: idx_case_motions_handling_prosecutor_text_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_handling_prosecutor_text_trgm ON public.case_motions USING gin (lower(handling_prosecutor_text) public.gin_trgm_ops);


--
-- Name: idx_case_motions_motion_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_motion_order ON public.case_motions USING btree (case_id, motion_order);


--
-- Name: idx_case_motions_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_name_trgm ON public.case_motions USING gin (lower(motion_name) public.gin_trgm_ops);


--
-- Name: idx_case_motions_status_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_status_trgm ON public.case_motions USING gin (lower(motion_status) public.gin_trgm_ops);


--
-- Name: idx_case_participant_attributes_case_participant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_attributes_case_participant_id ON public.case_participant_attributes USING btree (case_participant_id);


--
-- Name: idx_case_participant_attributes_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_attributes_legacy_row ON public.case_participant_attributes USING btree (legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_participant_attributes_minor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_attributes_minor ON public.case_participant_attributes USING btree (is_minor_at_case);


--
-- Name: idx_case_participant_attributes_pwd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_attributes_pwd ON public.case_participant_attributes USING btree (is_pwd_at_case);


--
-- Name: idx_case_participant_attributes_senior; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_attributes_senior ON public.case_participant_attributes USING btree (is_senior_at_case);


--
-- Name: idx_case_participant_private_details_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_private_details_case_id ON public.case_participant_private_details USING btree (case_id);


--
-- Name: idx_case_participant_private_details_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_private_details_legacy_row ON public.case_participant_private_details USING btree (legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_participant_relationships_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_relationships_case_id ON public.case_participant_relationships USING btree (case_id);


--
-- Name: idx_case_participant_relationships_from_participant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_relationships_from_participant ON public.case_participant_relationships USING btree (from_case_participant_id);


--
-- Name: idx_case_participant_relationships_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_relationships_legacy_row ON public.case_participant_relationships USING btree (legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_participant_relationships_to_participant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_relationships_to_participant ON public.case_participant_relationships USING btree (to_case_participant_id);


--
-- Name: idx_case_participants_case_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_case_person ON public.case_participants USING btree (case_id, person_id);


--
-- Name: idx_case_participants_case_role_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_case_role_order ON public.case_participants USING btree (case_id, role_id, participant_order);


--
-- Name: idx_case_participants_inv2022_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_inv2022_lookup ON public.case_participants USING btree (case_id, person_id, role_id);


--
-- Name: idx_case_participants_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_organization_id ON public.case_participants USING btree (organization_id);


--
-- Name: idx_case_participants_person_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_person_case ON public.case_participants USING btree (person_id, case_id);


--
-- Name: idx_case_petitions_review_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_petitions_review_case ON public.case_petitions_for_review USING btree (case_id);


--
-- Name: idx_case_petitions_review_date_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_petitions_review_date_received ON public.case_petitions_for_review USING btree (date_received DESC);


--
-- Name: idx_case_petitions_review_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_petitions_review_event ON public.case_petitions_for_review USING btree (case_event_id);


--
-- Name: idx_case_petitions_review_status_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_petitions_review_status_trgm ON public.case_petitions_for_review USING gin (lower(petition_status) public.gin_trgm_ops);


--
-- Name: idx_case_petitions_review_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_petitions_review_title_trgm ON public.case_petitions_for_review USING gin (lower(petition_title) public.gin_trgm_ops);


--
-- Name: idx_case_private_details_case_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_private_details_case_status ON public.case_private_details USING btree (case_id, current_status_id);


--
-- Name: idx_case_private_details_current_status_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_private_details_current_status_date ON public.case_private_details USING btree (current_status_date);


--
-- Name: idx_case_private_details_current_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_private_details_current_status_id ON public.case_private_details USING btree (current_status_id);


--
-- Name: idx_case_private_details_legacy_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_private_details_legacy_source ON public.case_private_details USING btree (legacy_source_file, legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_status_history_case_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_status_history_case_event_id ON public.case_status_history USING btree (case_event_id);


--
-- Name: idx_case_status_history_case_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_status_history_case_time ON public.case_status_history USING btree (case_id, changed_at DESC);


--
-- Name: idx_case_status_history_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_status_history_status ON public.case_status_history USING btree (to_status_id);


--
-- Name: idx_case_violations_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_violations_case_id ON public.case_violations USING btree (case_id);


--
-- Name: idx_case_violations_summary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_violations_summary ON public.case_violations USING btree (case_id, violation_order, violation_id);


--
-- Name: idx_case_violations_violation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_violations_violation_id ON public.case_violations USING btree (violation_id);


--
-- Name: idx_case_witness_details_case_participant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_witness_details_case_participant ON public.case_witness_details USING btree (case_participant_id);


--
-- Name: idx_case_witness_details_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_witness_details_legacy_row ON public.case_witness_details USING btree (legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_witness_details_side; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_witness_details_side ON public.case_witness_details USING btree (witness_side);


--
-- Name: idx_cases_case_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_case_classification_id ON public.cases USING btree (case_classification_id);


--
-- Name: idx_cases_created_id_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_created_id_desc ON public.cases USING btree (created_at DESC, id DESC);


--
-- Name: idx_cases_docket_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_docket_type ON public.cases USING btree (docket_type_id);


--
-- Name: idx_cases_docket_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_docket_type_id ON public.cases USING btree (docket_type_id);


--
-- Name: idx_cases_docket_type_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_docket_type_year ON public.cases USING btree (docket_type_id, docket_year, date_received DESC);


--
-- Name: idx_cases_list_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_list_order ON public.cases USING btree (docket_year DESC, docket_number DESC);


--
-- Name: idx_cases_region_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_region_month ON public.cases USING btree (region_code, docket_year, docket_month_code);


--
-- Name: idx_cases_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_year ON public.cases USING btree (docket_year);


--
-- Name: idx_clearance_phonetic_tokens_codes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_phonetic_tokens_codes ON public.clearance_phonetic_name_tokens USING gin (phonetic_codes);


--
-- Name: idx_clearance_phonetic_tokens_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_phonetic_tokens_person ON public.clearance_phonetic_name_tokens USING btree (person_id);


--
-- Name: idx_clearance_phonetic_tokens_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_phonetic_tokens_source ON public.clearance_phonetic_name_tokens USING btree (source_table);


--
-- Name: idx_clearance_phonetic_tokens_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_phonetic_tokens_token ON public.clearance_phonetic_name_tokens USING btree (token);


--
-- Name: idx_clearance_possible_tokens_bv_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_bv_key ON public.clearance_possible_name_tokens USING btree (bv_key);


--
-- Name: idx_clearance_possible_tokens_bv_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_bv_trgm ON public.clearance_possible_name_tokens USING gin (bv_key public.gin_trgm_ops);


--
-- Name: idx_clearance_possible_tokens_ck_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_ck_key ON public.clearance_possible_name_tokens USING btree (ck_key);


--
-- Name: idx_clearance_possible_tokens_ck_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_ck_trgm ON public.clearance_possible_name_tokens USING gin (ck_key public.gin_trgm_ops);


--
-- Name: idx_clearance_possible_tokens_first2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_first2 ON public.clearance_possible_name_tokens USING btree (first2);


--
-- Name: idx_clearance_possible_tokens_first3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_first3 ON public.clearance_possible_name_tokens USING btree (first3);


--
-- Name: idx_clearance_possible_tokens_last2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_last2 ON public.clearance_possible_name_tokens USING btree (last2);


--
-- Name: idx_clearance_possible_tokens_last3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_last3 ON public.clearance_possible_name_tokens USING btree (last3);


--
-- Name: idx_clearance_possible_tokens_len_first; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_len_first ON public.clearance_possible_name_tokens USING btree (token_len, first_char);


--
-- Name: idx_clearance_possible_tokens_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_person ON public.clearance_possible_name_tokens USING btree (person_id);


--
-- Name: idx_clearance_possible_tokens_phf_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_phf_key ON public.clearance_possible_name_tokens USING btree (phf_key);


--
-- Name: idx_clearance_possible_tokens_phf_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_phf_trgm ON public.clearance_possible_name_tokens USING gin (phf_key public.gin_trgm_ops);


--
-- Name: idx_clearance_possible_tokens_skeleton; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_skeleton ON public.clearance_possible_name_tokens USING btree (skeleton);


--
-- Name: idx_clearance_possible_tokens_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_source ON public.clearance_possible_name_tokens USING btree (source_table);


--
-- Name: idx_clearance_possible_tokens_sz_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_sz_key ON public.clearance_possible_name_tokens USING btree (sz_key);


--
-- Name: idx_clearance_possible_tokens_sz_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_sz_trgm ON public.clearance_possible_name_tokens USING gin (sz_key public.gin_trgm_ops);


--
-- Name: idx_clearance_possible_tokens_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_token ON public.clearance_possible_name_tokens USING btree (token);


--
-- Name: idx_clearance_possible_tokens_token_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_token_trgm ON public.clearance_possible_name_tokens USING gin (token public.gin_trgm_ops);


--
-- Name: idx_courts_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courts_type ON public.courts USING btree (court_type);


--
-- Name: idx_docket_number_history_case_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docket_number_history_case_time ON public.docket_number_history USING btree (case_id, changed_at DESC);


--
-- Name: idx_docket_number_history_display; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_docket_number_history_display ON public.docket_number_history USING btree (docket_display_number);


--
-- Name: idx_migration_review_items_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_migration_review_items_case_id ON public.migration_review_items USING btree (case_id);


--
-- Name: idx_migration_review_items_issue_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_migration_review_items_issue_type ON public.migration_review_items USING btree (issue_type);


--
-- Name: idx_migration_review_items_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_migration_review_items_legacy_row ON public.migration_review_items USING btree (legacy_source_file, legacy_source_sheet, legacy_row_number);


--
-- Name: idx_notes_case_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_case_time ON public.notes USING btree (case_id, created_at DESC);


--
-- Name: idx_notes_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_created_by ON public.notes USING btree (created_by_user_id);


--
-- Name: idx_organization_aliases_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_organization_aliases_name ON public.organization_aliases USING btree (lower(alias_name));


--
-- Name: idx_organizations_name_trgm_fallback; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_organizations_name_trgm_fallback ON public.organizations USING btree (lower(organization_name));


--
-- Name: idx_person_addresses_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_addresses_address ON public.person_addresses USING btree (address_id);


--
-- Name: idx_person_addresses_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_addresses_person ON public.person_addresses USING btree (person_id);


--
-- Name: idx_person_aliases_alias_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_aliases_alias_name_trgm ON public.person_aliases USING gin (alias_name public.gin_trgm_ops);


--
-- Name: idx_person_aliases_alias_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_aliases_alias_trgm ON public.person_aliases USING gin (alias_name public.gin_trgm_ops);


--
-- Name: idx_person_aliases_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_aliases_person ON public.person_aliases USING btree (person_id);


--
-- Name: idx_persons_first_name_metaphone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_first_name_metaphone ON public.persons USING btree (public.metaphone(lower(first_name), 8));


--
-- Name: idx_persons_full_name_metaphone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_full_name_metaphone ON public.persons USING btree (public.metaphone(lower(full_name), 12));


--
-- Name: idx_persons_full_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_full_name_trgm ON public.persons USING gin (lower(full_name) public.gin_trgm_ops);


--
-- Name: idx_persons_inv2022_full_name_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_inv2022_full_name_norm ON public.persons USING btree (upper(TRIM(BOTH FROM full_name)));


--
-- Name: idx_persons_last_name_metaphone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_last_name_metaphone ON public.persons USING btree (public.metaphone(lower(last_name), 8));


--
-- Name: idx_persons_name_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_name_lookup ON public.persons USING btree (last_name, first_name, middle_name);


--
-- Name: idx_prosecutor_staff_assignments_active_staff_prosecutor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prosecutor_staff_assignments_active_staff_prosecutor ON public.prosecutor_staff_assignments USING btree (staff_id, prosecutor_id) WHERE (is_active = true);


--
-- Name: idx_prosecutors_inv2022_short_name_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prosecutors_inv2022_short_name_norm ON public.prosecutors USING btree (upper(TRIM(BOTH FROM COALESCE(short_name, full_name))));


--
-- Name: idx_psa_prosecutor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psa_prosecutor ON public.prosecutor_staff_assignments USING btree (prosecutor_id);


--
-- Name: idx_psa_staff; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psa_staff ON public.prosecutor_staff_assignments USING btree (staff_id);


--
-- Name: idx_user_roles_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_roles_role_id ON public.user_roles USING btree (role_id);


--
-- Name: idx_users_auth_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_auth_user_id ON public.users USING btree (auth_user_id);


--
-- Name: idx_users_prosecutor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_prosecutor_id ON public.users USING btree (prosecutor_id) WHERE (prosecutor_id IS NOT NULL);


--
-- Name: idx_users_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_staff_id ON public.users USING btree (staff_id) WHERE (staff_id IS NOT NULL);


--
-- Name: idx_violations_inv2022_canonical_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_violations_inv2022_canonical_norm ON public.violations USING btree (public.inv2022_make_code(COALESCE(canonical_title, title)));


--
-- Name: one_active_assignment_per_case; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_assignment_per_case ON public.case_assignments USING btree (case_id) WHERE (unassigned_at IS NULL);


--
-- Name: one_active_prosecutor_staff_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_prosecutor_staff_pair ON public.prosecutor_staff_assignments USING btree (prosecutor_id, staff_id) WHERE (end_date IS NULL);


--
-- Name: ux_case_events_source_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_case_events_source_ref ON public.case_events USING btree (source_table, source_id) WHERE ((source_table IS NOT NULL) AND (source_id IS NOT NULL) AND (is_voided = false));


--
-- Name: ux_case_participant_relationship_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_case_participant_relationship_unique ON public.case_participant_relationships USING btree (case_id, from_case_participant_id, to_case_participant_id, relationship_type);


--
-- Name: ux_case_violations_case_violation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_case_violations_case_violation ON public.case_violations USING btree (case_id, violation_id);


--
-- Name: ux_organization_aliases_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_organization_aliases_active ON public.organization_aliases USING btree (organization_id, lower(btrim(alias_name))) WHERE (is_active = true);


--
-- Name: ux_organizations_name_type_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_organizations_name_type_active ON public.organizations USING btree (lower(btrim(organization_name)), organization_type) WHERE (is_active = true);


--
-- Name: ux_person_aliases_person_alias_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_person_aliases_person_alias_lower ON public.person_aliases USING btree (person_id, lower(alias_name));


--
-- Name: ux_users_auth_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_users_auth_user_id ON public.users USING btree (auth_user_id) WHERE (auth_user_id IS NOT NULL);


--
-- Name: ux_users_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_users_email_lower ON public.users USING btree (lower((email)::text));


--
-- Name: ux_violations_canonical_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_violations_canonical_title ON public.violations USING btree (canonical_title);


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_action_filter_selec; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_selec ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter, COALESCE(selected_columns, '{}'::text[]));


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_bucket_id_name_lower; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: case_legacy_attributes trg_case_legacy_attributes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_case_legacy_attributes_set_updated_at BEFORE UPDATE ON public.case_legacy_attributes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_now();


--
-- Name: case_participant_attributes trg_case_participant_attributes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_case_participant_attributes_set_updated_at BEFORE UPDATE ON public.case_participant_attributes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_now();


--
-- Name: case_participant_relationships trg_case_participant_relationships_same_case; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_case_participant_relationships_same_case BEFORE INSERT OR UPDATE OF case_id, from_case_participant_id, to_case_participant_id ON public.case_participant_relationships FOR EACH ROW EXECUTE FUNCTION public.trg_case_participant_relationships_same_case();


--
-- Name: case_participant_relationships trg_case_participant_relationships_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_case_participant_relationships_set_updated_at BEFORE UPDATE ON public.case_participant_relationships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_now();


--
-- Name: case_witness_details trg_case_witness_details_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_case_witness_details_set_updated_at BEFORE UPDATE ON public.case_witness_details FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_now();


--
-- Name: organization_aliases trg_organization_aliases_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_organization_aliases_set_updated_at BEFORE UPDATE ON public.organization_aliases FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_now();


--
-- Name: organizations trg_organizations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_organizations_set_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_now();


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: buckets protect_buckets_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects protect_objects_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: webauthn_challenges webauthn_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: webauthn_credentials webauthn_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id);


--
-- Name: case_addresses case_addresses_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_addresses
    ADD CONSTRAINT case_addresses_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id);


--
-- Name: case_addresses case_addresses_address_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_addresses
    ADD CONSTRAINT case_addresses_address_type_id_fkey FOREIGN KEY (address_type_id) REFERENCES public.address_types(id);


--
-- Name: case_addresses case_addresses_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_addresses
    ADD CONSTRAINT case_addresses_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_assignments case_assignments_assigned_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_assigned_by_user_id_fkey FOREIGN KEY (assigned_by_user_id) REFERENCES public.users(id);


--
-- Name: case_assignments case_assignments_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id) ON DELETE SET NULL;


--
-- Name: case_assignments case_assignments_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_assignments case_assignments_prosecutor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_prosecutor_id_fkey FOREIGN KEY (prosecutor_id) REFERENCES public.prosecutors(id);


--
-- Name: case_assignments case_assignments_prosecutor_staff_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_prosecutor_staff_assignment_id_fkey FOREIGN KEY (prosecutor_staff_assignment_id) REFERENCES public.prosecutor_staff_assignments(id);


--
-- Name: case_assignments case_assignments_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(id);


--
-- Name: case_attachment_index case_attachment_index_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attachment_index
    ADD CONSTRAINT case_attachment_index_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_attachment_index case_attachment_index_indexed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attachment_index
    ADD CONSTRAINT case_attachment_index_indexed_by_user_id_fkey FOREIGN KEY (indexed_by_user_id) REFERENCES public.users(id);


--
-- Name: case_courts case_courts_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_courts
    ADD CONSTRAINT case_courts_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id) ON DELETE SET NULL;


--
-- Name: case_courts case_courts_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_courts
    ADD CONSTRAINT case_courts_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_courts case_courts_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_courts
    ADD CONSTRAINT case_courts_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id);


--
-- Name: case_events case_events_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_events case_events_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id);


--
-- Name: case_events case_events_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_events case_events_event_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_event_type_id_fkey FOREIGN KEY (event_type_id) REFERENCES public.case_event_types(id);


--
-- Name: case_events case_events_prosecutor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_prosecutor_id_fkey FOREIGN KEY (prosecutor_id) REFERENCES public.prosecutors(id);


--
-- Name: case_events case_events_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(id);


--
-- Name: case_events case_events_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.case_statuses(id);


--
-- Name: case_events case_events_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_events case_events_voided_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_voided_by_user_id_fkey FOREIGN KEY (voided_by_user_id) REFERENCES public.users(id);


--
-- Name: case_legacy_attributes case_legacy_attributes_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_legacy_attributes
    ADD CONSTRAINT case_legacy_attributes_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_legacy_attributes case_legacy_attributes_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_legacy_attributes
    ADD CONSTRAINT case_legacy_attributes_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_legacy_attributes case_legacy_attributes_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_legacy_attributes
    ADD CONSTRAINT case_legacy_attributes_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_motions case_motions_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions
    ADD CONSTRAINT case_motions_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id) ON DELETE SET NULL;


--
-- Name: case_motions case_motions_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions
    ADD CONSTRAINT case_motions_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_motions case_motions_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions
    ADD CONSTRAINT case_motions_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_motions case_motions_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions
    ADD CONSTRAINT case_motions_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_participant_attributes case_participant_attributes_case_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_attributes
    ADD CONSTRAINT case_participant_attributes_case_participant_id_fkey FOREIGN KEY (case_participant_id) REFERENCES public.case_participants(id) ON DELETE CASCADE;


--
-- Name: case_participant_attributes case_participant_attributes_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_attributes
    ADD CONSTRAINT case_participant_attributes_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_participant_attributes case_participant_attributes_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_attributes
    ADD CONSTRAINT case_participant_attributes_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_participant_private_details case_participant_private_details_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_private_details
    ADD CONSTRAINT case_participant_private_details_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_participant_private_details case_participant_private_details_case_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_private_details
    ADD CONSTRAINT case_participant_private_details_case_participant_id_fkey FOREIGN KEY (case_participant_id) REFERENCES public.case_participants(id) ON DELETE CASCADE;


--
-- Name: case_participant_relationships case_participant_relationships_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_relationships
    ADD CONSTRAINT case_participant_relationships_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_participant_relationships case_participant_relationships_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_relationships
    ADD CONSTRAINT case_participant_relationships_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_participant_relationships case_participant_relationships_from_case_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_relationships
    ADD CONSTRAINT case_participant_relationships_from_case_participant_id_fkey FOREIGN KEY (from_case_participant_id) REFERENCES public.case_participants(id) ON DELETE CASCADE;


--
-- Name: case_participant_relationships case_participant_relationships_to_case_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_relationships
    ADD CONSTRAINT case_participant_relationships_to_case_participant_id_fkey FOREIGN KEY (to_case_participant_id) REFERENCES public.case_participants(id) ON DELETE CASCADE;


--
-- Name: case_participant_relationships case_participant_relationships_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_relationships
    ADD CONSTRAINT case_participant_relationships_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_participants case_participants_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participants
    ADD CONSTRAINT case_participants_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_participants case_participants_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participants
    ADD CONSTRAINT case_participants_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: case_participants case_participants_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participants
    ADD CONSTRAINT case_participants_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id);


--
-- Name: case_participants case_participants_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participants
    ADD CONSTRAINT case_participants_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.participant_roles(id);


--
-- Name: case_petitions_for_review case_petitions_for_review_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_petitions_for_review
    ADD CONSTRAINT case_petitions_for_review_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id) ON DELETE SET NULL;


--
-- Name: case_petitions_for_review case_petitions_for_review_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_petitions_for_review
    ADD CONSTRAINT case_petitions_for_review_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_petitions_for_review case_petitions_for_review_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_petitions_for_review
    ADD CONSTRAINT case_petitions_for_review_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_petitions_for_review case_petitions_for_review_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_petitions_for_review
    ADD CONSTRAINT case_petitions_for_review_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_private_details case_private_details_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_private_details
    ADD CONSTRAINT case_private_details_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_private_details case_private_details_current_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_private_details
    ADD CONSTRAINT case_private_details_current_status_id_fkey FOREIGN KEY (current_status_id) REFERENCES public.case_statuses(id);


--
-- Name: case_status_colors case_status_colors_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_colors
    ADD CONSTRAINT case_status_colors_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.case_statuses(id) ON DELETE CASCADE;


--
-- Name: case_status_history case_status_history_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_history
    ADD CONSTRAINT case_status_history_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id) ON DELETE SET NULL;


--
-- Name: case_status_history case_status_history_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_history
    ADD CONSTRAINT case_status_history_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_status_history case_status_history_changed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_history
    ADD CONSTRAINT case_status_history_changed_by_user_id_fkey FOREIGN KEY (changed_by_user_id) REFERENCES public.users(id);


--
-- Name: case_status_history case_status_history_from_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_history
    ADD CONSTRAINT case_status_history_from_status_id_fkey FOREIGN KEY (from_status_id) REFERENCES public.case_statuses(id);


--
-- Name: case_status_history case_status_history_to_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_history
    ADD CONSTRAINT case_status_history_to_status_id_fkey FOREIGN KEY (to_status_id) REFERENCES public.case_statuses(id);


--
-- Name: case_violations case_violations_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_violations
    ADD CONSTRAINT case_violations_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_violations case_violations_violation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_violations
    ADD CONSTRAINT case_violations_violation_id_fkey FOREIGN KEY (violation_id) REFERENCES public.violations(id);


--
-- Name: case_witness_details case_witness_details_case_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_witness_details
    ADD CONSTRAINT case_witness_details_case_participant_id_fkey FOREIGN KEY (case_participant_id) REFERENCES public.case_participants(id) ON DELETE CASCADE;


--
-- Name: case_witness_details case_witness_details_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_witness_details
    ADD CONSTRAINT case_witness_details_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_witness_details case_witness_details_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_witness_details
    ADD CONSTRAINT case_witness_details_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: cases cases_case_classification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_case_classification_id_fkey FOREIGN KEY (case_classification_id) REFERENCES public.case_classifications(id);


--
-- Name: cases cases_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: cases cases_docket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_docket_type_id_fkey FOREIGN KEY (docket_type_id) REFERENCES public.docket_types(id);


--
-- Name: cases cases_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: clearance_phonetic_name_tokens clearance_phonetic_name_tokens_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clearance_phonetic_name_tokens
    ADD CONSTRAINT clearance_phonetic_name_tokens_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON DELETE CASCADE;


--
-- Name: clearance_possible_name_tokens clearance_possible_name_tokens_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clearance_possible_name_tokens
    ADD CONSTRAINT clearance_possible_name_tokens_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON DELETE CASCADE;


--
-- Name: docket_number_history docket_number_history_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_number_history
    ADD CONSTRAINT docket_number_history_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: docket_number_history docket_number_history_changed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_number_history
    ADD CONSTRAINT docket_number_history_changed_by_user_id_fkey FOREIGN KEY (changed_by_user_id) REFERENCES public.users(id);


--
-- Name: docket_number_history docket_number_history_docket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_number_history
    ADD CONSTRAINT docket_number_history_docket_type_id_fkey FOREIGN KEY (docket_type_id) REFERENCES public.docket_types(id);


--
-- Name: docket_sequence_counters docket_sequence_counters_docket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.docket_sequence_counters
    ADD CONSTRAINT docket_sequence_counters_docket_type_id_fkey FOREIGN KEY (docket_type_id) REFERENCES public.docket_types(id);


--
-- Name: migration_review_items migration_review_items_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migration_review_items
    ADD CONSTRAINT migration_review_items_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: migration_review_items migration_review_items_resolved_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migration_review_items
    ADD CONSTRAINT migration_review_items_resolved_by_user_id_fkey FOREIGN KEY (resolved_by_user_id) REFERENCES public.users(id);


--
-- Name: notes notes_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: notes notes_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: organization_aliases organization_aliases_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_aliases
    ADD CONSTRAINT organization_aliases_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: organizations organizations_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: organizations organizations_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: person_addresses person_addresses_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_addresses
    ADD CONSTRAINT person_addresses_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id) ON DELETE CASCADE;


--
-- Name: person_addresses person_addresses_address_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_addresses
    ADD CONSTRAINT person_addresses_address_type_id_fkey FOREIGN KEY (address_type_id) REFERENCES public.address_types(id);


--
-- Name: person_addresses person_addresses_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_addresses
    ADD CONSTRAINT person_addresses_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON DELETE CASCADE;


--
-- Name: person_aliases person_aliases_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_aliases
    ADD CONSTRAINT person_aliases_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON DELETE CASCADE;


--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_assigned_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutor_staff_assignments
    ADD CONSTRAINT prosecutor_staff_assignments_assigned_by_user_id_fkey FOREIGN KEY (assigned_by_user_id) REFERENCES public.users(id);


--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_prosecutor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutor_staff_assignments
    ADD CONSTRAINT prosecutor_staff_assignments_prosecutor_id_fkey FOREIGN KEY (prosecutor_id) REFERENCES public.prosecutors(id);


--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutor_staff_assignments
    ADD CONSTRAINT prosecutor_staff_assignments_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(id);


--
-- Name: prosecutors prosecutors_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prosecutors
    ADD CONSTRAINT prosecutors_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id);


--
-- Name: staff staff_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_auth_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: users users_prosecutor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_prosecutor_id_fkey FOREIGN KEY (prosecutor_id) REFERENCES public.prosecutors(id);


--
-- Name: users users_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(id);


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: address_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.address_types ENABLE ROW LEVEL SECURITY;

--
-- Name: address_types address_types_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY address_types_delete_developer_only ON public.address_types FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: address_types address_types_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY address_types_insert_by_seed_managers ON public.address_types FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: address_types address_types_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY address_types_select_for_app_users ON public.address_types FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: address_types address_types_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY address_types_update_by_seed_managers ON public.address_types FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: addresses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

--
-- Name: addresses addresses_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY addresses_delete_developer_only ON public.addresses FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: addresses addresses_insert_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY addresses_insert_by_identity_managers ON public.addresses FOR INSERT TO authenticated WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: addresses addresses_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY addresses_select_by_case_access ON public.addresses FOR SELECT TO authenticated USING ((public.can_view_address_details(id) OR public.can_manage_master_identity_data()));


--
-- Name: addresses addresses_update_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY addresses_update_by_identity_managers ON public.addresses FOR UPDATE TO authenticated USING (public.can_manage_master_identity_data()) WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_logs_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_delete_developer_only ON public.audit_logs FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: audit_logs audit_logs_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_insert_developer_only ON public.audit_logs FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: audit_logs audit_logs_select_by_audit_viewers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_select_by_audit_viewers ON public.audit_logs FOR SELECT TO authenticated USING (public.can_view_audit_logs());


--
-- Name: audit_logs audit_logs_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_update_developer_only ON public.audit_logs FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: case_addresses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_addresses ENABLE ROW LEVEL SECURITY;

--
-- Name: case_addresses case_addresses_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_addresses_delete_developer_only ON public.case_addresses FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_addresses case_addresses_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_addresses_insert_by_case_access ON public.case_addresses FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_addresses case_addresses_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_addresses_select_by_case_access ON public.case_addresses FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_addresses case_addresses_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_addresses_update_by_case_access ON public.case_addresses FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: case_assignments case_assignments_delete_by_assignment_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_assignments_delete_by_assignment_managers ON public.case_assignments FOR DELETE TO authenticated USING (public.can_assign_case());


--
-- Name: case_assignments case_assignments_insert_by_assignment_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_assignments_insert_by_assignment_managers ON public.case_assignments FOR INSERT TO authenticated WITH CHECK (public.can_assign_case());


--
-- Name: case_assignments case_assignments_select_by_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_assignments_select_by_access ON public.case_assignments FOR SELECT TO authenticated USING ((public.can_assign_case() OR public.can_view_case_details(case_id)));


--
-- Name: case_assignments case_assignments_update_by_assignment_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_assignments_update_by_assignment_managers ON public.case_assignments FOR UPDATE TO authenticated USING (public.can_assign_case()) WITH CHECK (public.can_assign_case());


--
-- Name: case_attachment_index; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_attachment_index ENABLE ROW LEVEL SECURITY;

--
-- Name: case_attachment_index case_attachment_index_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_attachment_index_delete_developer_only ON public.case_attachment_index FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_attachment_index case_attachment_index_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_attachment_index_insert_by_case_access ON public.case_attachment_index FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_attachment_index case_attachment_index_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_attachment_index_select_by_case_access ON public.case_attachment_index FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_attachment_index case_attachment_index_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_attachment_index_update_by_case_access ON public.case_attachment_index FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_classifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_classifications ENABLE ROW LEVEL SECURITY;

--
-- Name: case_classifications case_classifications_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_classifications_delete_developer_only ON public.case_classifications FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: case_classifications case_classifications_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_classifications_insert_by_seed_managers ON public.case_classifications FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_classifications case_classifications_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_classifications_select_for_app_users ON public.case_classifications FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: case_classifications case_classifications_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_classifications_update_by_seed_managers ON public.case_classifications FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_courts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_courts ENABLE ROW LEVEL SECURITY;

--
-- Name: case_courts case_courts_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_courts_delete_developer_only ON public.case_courts FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_courts case_courts_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_courts_insert_by_case_access ON public.case_courts FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_courts case_courts_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_courts_select_by_case_access ON public.case_courts FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_courts case_courts_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_courts_update_by_case_access ON public.case_courts FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_event_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_event_types ENABLE ROW LEVEL SECURITY;

--
-- Name: case_event_types case_event_types_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_event_types_delete_developer_only ON public.case_event_types FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: case_event_types case_event_types_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_event_types_insert_by_seed_managers ON public.case_event_types FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_event_types case_event_types_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_event_types_select_for_app_users ON public.case_event_types FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: case_event_types case_event_types_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_event_types_update_by_seed_managers ON public.case_event_types FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_events ENABLE ROW LEVEL SECURITY;

--
-- Name: case_events case_events_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_events_delete_developer_only ON public.case_events FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_events case_events_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_events_insert_by_case_access ON public.case_events FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_events case_events_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_events_select_by_case_access ON public.case_events FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_events case_events_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_events_update_by_case_access ON public.case_events FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_legacy_attributes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_legacy_attributes ENABLE ROW LEVEL SECURITY;

--
-- Name: case_legacy_attributes case_legacy_attributes_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_legacy_attributes_delete_developer_only ON public.case_legacy_attributes FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_legacy_attributes case_legacy_attributes_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_legacy_attributes_insert_by_case_access ON public.case_legacy_attributes FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details((case_id)::bigint));


--
-- Name: case_legacy_attributes case_legacy_attributes_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_legacy_attributes_select_by_case_access ON public.case_legacy_attributes FOR SELECT TO authenticated USING (public.can_view_case_details((case_id)::bigint));


--
-- Name: case_legacy_attributes case_legacy_attributes_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_legacy_attributes_update_by_case_access ON public.case_legacy_attributes FOR UPDATE TO authenticated USING (public.can_edit_case_details((case_id)::bigint)) WITH CHECK (public.can_edit_case_details((case_id)::bigint));


--
-- Name: case_motions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_motions ENABLE ROW LEVEL SECURITY;

--
-- Name: case_motions case_motions_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_motions_delete_developer_only ON public.case_motions FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_motions case_motions_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_motions_insert_by_case_access ON public.case_motions FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_motions case_motions_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_motions_select_by_case_access ON public.case_motions FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_motions case_motions_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_motions_update_by_case_access ON public.case_motions FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_participant_attributes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_participant_attributes ENABLE ROW LEVEL SECURITY;

--
-- Name: case_participant_attributes case_participant_attributes_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_attributes_delete_developer_only ON public.case_participant_attributes FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_participant_attributes case_participant_attributes_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_attributes_insert_by_case_access ON public.case_participant_attributes FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_participant_details((case_participant_id)::bigint));


--
-- Name: case_participant_attributes case_participant_attributes_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_attributes_select_by_case_access ON public.case_participant_attributes FOR SELECT TO authenticated USING (public.can_view_case_participant_details((case_participant_id)::bigint));


--
-- Name: case_participant_attributes case_participant_attributes_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_attributes_update_by_case_access ON public.case_participant_attributes FOR UPDATE TO authenticated USING (public.can_edit_case_participant_details((case_participant_id)::bigint)) WITH CHECK (public.can_edit_case_participant_details((case_participant_id)::bigint));


--
-- Name: case_participant_private_details; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_participant_private_details ENABLE ROW LEVEL SECURITY;

--
-- Name: case_participant_private_details case_participant_private_details_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_private_details_delete_developer_only ON public.case_participant_private_details FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_participant_private_details case_participant_private_details_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_private_details_insert_by_case_access ON public.case_participant_private_details FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_participant_private_details case_participant_private_details_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_private_details_select_by_case_access ON public.case_participant_private_details FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_participant_private_details case_participant_private_details_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_private_details_update_by_case_access ON public.case_participant_private_details FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_participant_relationships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_participant_relationships ENABLE ROW LEVEL SECURITY;

--
-- Name: case_participant_relationships case_participant_relationships_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_relationships_delete_developer_only ON public.case_participant_relationships FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_participant_relationships case_participant_relationships_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_relationships_insert_by_case_access ON public.case_participant_relationships FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details((case_id)::bigint));


--
-- Name: case_participant_relationships case_participant_relationships_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_relationships_select_by_case_access ON public.case_participant_relationships FOR SELECT TO authenticated USING (public.can_view_case_details((case_id)::bigint));


--
-- Name: case_participant_relationships case_participant_relationships_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participant_relationships_update_by_case_access ON public.case_participant_relationships FOR UPDATE TO authenticated USING (public.can_edit_case_details((case_id)::bigint)) WITH CHECK (public.can_edit_case_details((case_id)::bigint));


--
-- Name: case_participants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_participants ENABLE ROW LEVEL SECURITY;

--
-- Name: case_participants case_participants_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participants_delete_developer_only ON public.case_participants FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_participants case_participants_insert_by_case_editors; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participants_insert_by_case_editors ON public.case_participants FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_participants case_participants_select_header_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participants_select_header_for_app_users ON public.case_participants FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: case_participants case_participants_update_by_case_editors; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_participants_update_by_case_editors ON public.case_participants FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_petitions_for_review; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_petitions_for_review ENABLE ROW LEVEL SECURITY;

--
-- Name: case_petitions_for_review case_petitions_for_review_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_petitions_for_review_delete_developer_only ON public.case_petitions_for_review FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_petitions_for_review case_petitions_for_review_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_petitions_for_review_insert_by_case_access ON public.case_petitions_for_review FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_petitions_for_review case_petitions_for_review_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_petitions_for_review_select_by_case_access ON public.case_petitions_for_review FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_petitions_for_review case_petitions_for_review_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_petitions_for_review_update_by_case_access ON public.case_petitions_for_review FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_private_details; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_private_details ENABLE ROW LEVEL SECURITY;

--
-- Name: case_private_details case_private_details_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_private_details_delete_developer_only ON public.case_private_details FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_private_details case_private_details_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_private_details_insert_by_case_access ON public.case_private_details FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_private_details case_private_details_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_private_details_select_by_case_access ON public.case_private_details FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_private_details case_private_details_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_private_details_update_by_case_access ON public.case_private_details FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_status_colors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_status_colors ENABLE ROW LEVEL SECURITY;

--
-- Name: case_status_colors case_status_colors_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_colors_delete_developer_only ON public.case_status_colors FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: case_status_colors case_status_colors_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_colors_insert_by_seed_managers ON public.case_status_colors FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_status_colors case_status_colors_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_colors_select_for_app_users ON public.case_status_colors FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: case_status_colors case_status_colors_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_colors_update_by_seed_managers ON public.case_status_colors FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_status_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_status_history ENABLE ROW LEVEL SECURITY;

--
-- Name: case_status_history case_status_history_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_history_delete_developer_only ON public.case_status_history FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_status_history case_status_history_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_history_insert_by_case_access ON public.case_status_history FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_status_history case_status_history_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_history_select_by_case_access ON public.case_status_history FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: case_status_history case_status_history_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_status_history_update_by_case_access ON public.case_status_history FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_statuses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_statuses ENABLE ROW LEVEL SECURITY;

--
-- Name: case_statuses case_statuses_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_statuses_delete_developer_only ON public.case_statuses FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: case_statuses case_statuses_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_statuses_insert_by_seed_managers ON public.case_statuses FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_statuses case_statuses_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_statuses_select_for_app_users ON public.case_statuses FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: case_statuses case_statuses_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_statuses_update_by_seed_managers ON public.case_statuses FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: case_violations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_violations ENABLE ROW LEVEL SECURITY;

--
-- Name: case_violations case_violations_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_violations_delete_developer_only ON public.case_violations FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_violations case_violations_insert_by_case_editors; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_violations_insert_by_case_editors ON public.case_violations FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_violations case_violations_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_violations_select_for_app_users ON public.case_violations FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: case_violations case_violations_update_by_case_editors; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_violations_update_by_case_editors ON public.case_violations FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: case_witness_details; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.case_witness_details ENABLE ROW LEVEL SECURITY;

--
-- Name: case_witness_details case_witness_details_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_witness_details_delete_developer_only ON public.case_witness_details FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: case_witness_details case_witness_details_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_witness_details_insert_by_case_access ON public.case_witness_details FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_participant_details((case_participant_id)::bigint));


--
-- Name: case_witness_details case_witness_details_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_witness_details_select_by_case_access ON public.case_witness_details FOR SELECT TO authenticated USING (public.can_view_case_participant_details((case_participant_id)::bigint));


--
-- Name: case_witness_details case_witness_details_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY case_witness_details_update_by_case_access ON public.case_witness_details FOR UPDATE TO authenticated USING (public.can_edit_case_participant_details((case_participant_id)::bigint)) WITH CHECK (public.can_edit_case_participant_details((case_participant_id)::bigint));


--
-- Name: cases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;

--
-- Name: cases cases_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cases_delete_developer_only ON public.cases FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: cases cases_insert_by_case_creators; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cases_insert_by_case_creators ON public.cases FOR INSERT TO authenticated WITH CHECK (public.can_create_case());


--
-- Name: cases cases_select_header_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cases_select_header_for_app_users ON public.cases FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: cases cases_update_by_case_header_editors; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cases_update_by_case_header_editors ON public.cases FOR UPDATE TO authenticated USING (public.can_edit_case_header()) WITH CHECK (public.can_edit_case_header());


--
-- Name: clearance_phonetic_name_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.clearance_phonetic_name_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: clearance_phonetic_name_tokens clearance_phonetic_name_tokens_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_phonetic_name_tokens_delete_developer_only ON public.clearance_phonetic_name_tokens FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: clearance_phonetic_name_tokens clearance_phonetic_name_tokens_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_phonetic_name_tokens_insert_developer_only ON public.clearance_phonetic_name_tokens FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: clearance_phonetic_name_tokens clearance_phonetic_name_tokens_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_phonetic_name_tokens_select_developer_only ON public.clearance_phonetic_name_tokens FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: clearance_phonetic_name_tokens clearance_phonetic_name_tokens_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_phonetic_name_tokens_update_developer_only ON public.clearance_phonetic_name_tokens FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: clearance_possible_name_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.clearance_possible_name_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: clearance_possible_name_tokens clearance_possible_name_tokens_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_possible_name_tokens_delete_developer_only ON public.clearance_possible_name_tokens FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: clearance_possible_name_tokens clearance_possible_name_tokens_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_possible_name_tokens_insert_developer_only ON public.clearance_possible_name_tokens FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: clearance_possible_name_tokens clearance_possible_name_tokens_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_possible_name_tokens_select_developer_only ON public.clearance_possible_name_tokens FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: clearance_possible_name_tokens clearance_possible_name_tokens_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clearance_possible_name_tokens_update_developer_only ON public.clearance_possible_name_tokens FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: courts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.courts ENABLE ROW LEVEL SECURITY;

--
-- Name: courts courts_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY courts_delete_developer_only ON public.courts FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: courts courts_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY courts_insert_by_seed_managers ON public.courts FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: courts courts_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY courts_select_for_app_users ON public.courts FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: courts courts_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY courts_update_by_seed_managers ON public.courts FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: docket_number_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.docket_number_history ENABLE ROW LEVEL SECURITY;

--
-- Name: docket_number_history docket_number_history_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_number_history_delete_developer_only ON public.docket_number_history FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: docket_number_history docket_number_history_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_number_history_insert_by_case_access ON public.docket_number_history FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: docket_number_history docket_number_history_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_number_history_select_by_case_access ON public.docket_number_history FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: docket_number_history docket_number_history_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_number_history_update_by_case_access ON public.docket_number_history FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: docket_sequence_counters; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.docket_sequence_counters ENABLE ROW LEVEL SECURITY;

--
-- Name: docket_sequence_counters docket_sequence_counters_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_sequence_counters_delete_developer_only ON public.docket_sequence_counters FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: docket_sequence_counters docket_sequence_counters_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_sequence_counters_insert_developer_only ON public.docket_sequence_counters FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: docket_sequence_counters docket_sequence_counters_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_sequence_counters_select_developer_only ON public.docket_sequence_counters FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: docket_sequence_counters docket_sequence_counters_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_sequence_counters_update_developer_only ON public.docket_sequence_counters FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: docket_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.docket_types ENABLE ROW LEVEL SECURITY;

--
-- Name: docket_types docket_types_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_types_delete_developer_only ON public.docket_types FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: docket_types docket_types_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_types_insert_by_seed_managers ON public.docket_types FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: docket_types docket_types_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_types_select_for_app_users ON public.docket_types FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: docket_types docket_types_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY docket_types_update_by_seed_managers ON public.docket_types FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: migration_review_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.migration_review_items ENABLE ROW LEVEL SECURITY;

--
-- Name: migration_review_items migration_review_items_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY migration_review_items_delete_developer_only ON public.migration_review_items FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: migration_review_items migration_review_items_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY migration_review_items_insert_developer_only ON public.migration_review_items FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: migration_review_items migration_review_items_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY migration_review_items_select_developer_only ON public.migration_review_items FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: migration_review_items migration_review_items_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY migration_review_items_update_developer_only ON public.migration_review_items FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

--
-- Name: notes notes_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_delete_developer_only ON public.notes FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: notes notes_insert_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_insert_by_case_access ON public.notes FOR INSERT TO authenticated WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: notes notes_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_select_by_case_access ON public.notes FOR SELECT TO authenticated USING (public.can_view_case_details(case_id));


--
-- Name: notes notes_update_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_update_by_case_access ON public.notes FOR UPDATE TO authenticated USING (public.can_edit_case_details(case_id)) WITH CHECK (public.can_edit_case_details(case_id));


--
-- Name: organization_aliases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organization_aliases ENABLE ROW LEVEL SECURITY;

--
-- Name: organization_aliases organization_aliases_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_aliases_delete_developer_only ON public.organization_aliases FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: organization_aliases organization_aliases_insert_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_aliases_insert_by_identity_managers ON public.organization_aliases FOR INSERT TO authenticated WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: organization_aliases organization_aliases_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_aliases_select_by_case_access ON public.organization_aliases FOR SELECT TO authenticated USING ((public.can_view_organization_details(organization_id) OR public.can_manage_master_identity_data()));


--
-- Name: organization_aliases organization_aliases_update_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_aliases_update_by_identity_managers ON public.organization_aliases FOR UPDATE TO authenticated USING (public.can_manage_master_identity_data()) WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: organizations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

--
-- Name: organizations organizations_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_delete_developer_only ON public.organizations FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: organizations organizations_insert_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_insert_by_identity_managers ON public.organizations FOR INSERT TO authenticated WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: organizations organizations_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_select_by_case_access ON public.organizations FOR SELECT TO authenticated USING ((public.can_view_organization_details(id) OR public.can_manage_master_identity_data()));


--
-- Name: organizations organizations_update_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_update_by_identity_managers ON public.organizations FOR UPDATE TO authenticated USING (public.can_manage_master_identity_data()) WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: participant_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.participant_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: participant_roles participant_roles_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY participant_roles_delete_developer_only ON public.participant_roles FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: participant_roles participant_roles_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY participant_roles_insert_by_seed_managers ON public.participant_roles FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: participant_roles participant_roles_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY participant_roles_select_for_app_users ON public.participant_roles FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: participant_roles participant_roles_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY participant_roles_update_by_seed_managers ON public.participant_roles FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: person_addresses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.person_addresses ENABLE ROW LEVEL SECURITY;

--
-- Name: person_addresses person_addresses_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_addresses_delete_developer_only ON public.person_addresses FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: person_addresses person_addresses_insert_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_addresses_insert_by_identity_managers ON public.person_addresses FOR INSERT TO authenticated WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: person_addresses person_addresses_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_addresses_select_by_case_access ON public.person_addresses FOR SELECT TO authenticated USING ((public.can_view_person_details(person_id) OR public.can_manage_master_identity_data()));


--
-- Name: person_addresses person_addresses_update_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_addresses_update_by_identity_managers ON public.person_addresses FOR UPDATE TO authenticated USING (public.can_manage_master_identity_data()) WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: person_aliases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.person_aliases ENABLE ROW LEVEL SECURITY;

--
-- Name: person_aliases person_aliases_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_aliases_delete_developer_only ON public.person_aliases FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: person_aliases person_aliases_insert_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_aliases_insert_by_identity_managers ON public.person_aliases FOR INSERT TO authenticated WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: person_aliases person_aliases_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_aliases_select_by_case_access ON public.person_aliases FOR SELECT TO authenticated USING ((public.can_view_person_details(person_id) OR public.can_manage_master_identity_data()));


--
-- Name: person_aliases person_aliases_update_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY person_aliases_update_by_identity_managers ON public.person_aliases FOR UPDATE TO authenticated USING (public.can_manage_master_identity_data()) WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: persons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;

--
-- Name: persons persons_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY persons_delete_developer_only ON public.persons FOR DELETE TO authenticated USING (public.can_delete_case());


--
-- Name: persons persons_insert_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY persons_insert_by_identity_managers ON public.persons FOR INSERT TO authenticated WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: persons persons_select_by_case_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY persons_select_by_case_access ON public.persons FOR SELECT TO authenticated USING ((public.can_view_person_details(id) OR public.can_manage_master_identity_data()));


--
-- Name: persons persons_update_by_identity_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY persons_update_by_identity_managers ON public.persons FOR UPDATE TO authenticated USING (public.can_manage_master_identity_data()) WITH CHECK (public.can_manage_master_identity_data());


--
-- Name: positions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.positions ENABLE ROW LEVEL SECURITY;

--
-- Name: positions positions_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY positions_delete_developer_only ON public.positions FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: positions positions_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY positions_insert_by_seed_managers ON public.positions FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: positions positions_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY positions_select_for_app_users ON public.positions FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: positions positions_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY positions_update_by_seed_managers ON public.positions FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: prosecutor_staff_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prosecutor_staff_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_delete_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutor_staff_assignments_delete_by_user_managers ON public.prosecutor_staff_assignments FOR DELETE TO authenticated USING (public.can_manage_users());


--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_insert_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutor_staff_assignments_insert_by_user_managers ON public.prosecutor_staff_assignments FOR INSERT TO authenticated WITH CHECK (public.can_manage_users());


--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_select_by_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutor_staff_assignments_select_by_access ON public.prosecutor_staff_assignments FOR SELECT TO authenticated USING ((public.can_manage_users() OR (prosecutor_id = public.current_app_prosecutor_id()) OR (staff_id = public.current_app_staff_id())));


--
-- Name: prosecutor_staff_assignments prosecutor_staff_assignments_update_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutor_staff_assignments_update_by_user_managers ON public.prosecutor_staff_assignments FOR UPDATE TO authenticated USING (public.can_manage_users()) WITH CHECK (public.can_manage_users());


--
-- Name: prosecutors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prosecutors ENABLE ROW LEVEL SECURITY;

--
-- Name: prosecutors prosecutors_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutors_delete_developer_only ON public.prosecutors FOR DELETE TO authenticated USING (public.has_app_role('DEVELOPER'::text));


--
-- Name: prosecutors prosecutors_insert_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutors_insert_by_user_managers ON public.prosecutors FOR INSERT TO authenticated WITH CHECK (public.can_manage_users());


--
-- Name: prosecutors prosecutors_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutors_select_for_app_users ON public.prosecutors FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: prosecutors prosecutors_update_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prosecutors_update_by_user_managers ON public.prosecutors FOR UPDATE TO authenticated USING (public.can_manage_users()) WITH CHECK (public.can_manage_users());


--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: roles roles_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_delete_developer_only ON public.roles FOR DELETE TO authenticated USING (public.has_app_role('DEVELOPER'::text));


--
-- Name: roles roles_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_insert_developer_only ON public.roles FOR INSERT TO authenticated WITH CHECK (public.has_app_role('DEVELOPER'::text));


--
-- Name: roles roles_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_select_for_app_users ON public.roles FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: roles roles_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_update_developer_only ON public.roles FOR UPDATE TO authenticated USING (public.has_app_role('DEVELOPER'::text)) WITH CHECK (public.has_app_role('DEVELOPER'::text));


--
-- Name: staff; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;

--
-- Name: staff staff_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staff_delete_developer_only ON public.staff FOR DELETE TO authenticated USING (public.has_app_role('DEVELOPER'::text));


--
-- Name: staff staff_insert_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staff_insert_by_user_managers ON public.staff FOR INSERT TO authenticated WITH CHECK (public.can_manage_users());


--
-- Name: staff staff_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staff_select_for_app_users ON public.staff FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: staff staff_update_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staff_update_by_user_managers ON public.staff FOR UPDATE TO authenticated USING (public.can_manage_users()) WITH CHECK (public.can_manage_users());


--
-- Name: staging_dc2025_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_dc2025_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_dc2025_normalized_rows staging_dc2025_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_dc2025_normalized_rows_delete_developer_only ON public.staging_dc2025_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_dc2025_normalized_rows staging_dc2025_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_dc2025_normalized_rows_insert_developer_only ON public.staging_dc2025_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_dc2025_normalized_rows staging_dc2025_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_dc2025_normalized_rows_select_developer_only ON public.staging_dc2025_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_dc2025_normalized_rows staging_dc2025_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_dc2025_normalized_rows_update_developer_only ON public.staging_dc2025_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2022_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2022_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inq2022_normalized_rows staging_inq2022_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2022_normalized_rows_delete_developer_only ON public.staging_inq2022_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2022_normalized_rows staging_inq2022_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2022_normalized_rows_insert_developer_only ON public.staging_inq2022_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2022_normalized_rows staging_inq2022_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2022_normalized_rows_select_developer_only ON public.staging_inq2022_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2022_normalized_rows staging_inq2022_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2022_normalized_rows_update_developer_only ON public.staging_inq2022_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2023_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2023_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inq2023_normalized_rows staging_inq2023_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2023_normalized_rows_delete_developer_only ON public.staging_inq2023_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2023_normalized_rows staging_inq2023_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2023_normalized_rows_insert_developer_only ON public.staging_inq2023_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2023_normalized_rows staging_inq2023_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2023_normalized_rows_select_developer_only ON public.staging_inq2023_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2023_normalized_rows staging_inq2023_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2023_normalized_rows_update_developer_only ON public.staging_inq2023_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2024_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2024_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inq2024_normalized_rows staging_inq2024_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2024_normalized_rows_delete_developer_only ON public.staging_inq2024_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2024_normalized_rows staging_inq2024_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2024_normalized_rows_insert_developer_only ON public.staging_inq2024_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2024_normalized_rows staging_inq2024_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2024_normalized_rows_select_developer_only ON public.staging_inq2024_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2024_normalized_rows staging_inq2024_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2024_normalized_rows_update_developer_only ON public.staging_inq2024_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2025_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inq2025_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inq2025_normalized_rows staging_inq2025_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2025_normalized_rows_delete_developer_only ON public.staging_inq2025_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2025_normalized_rows staging_inq2025_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2025_normalized_rows_insert_developer_only ON public.staging_inq2025_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inq2025_normalized_rows staging_inq2025_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2025_normalized_rows_select_developer_only ON public.staging_inq2025_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inq2025_normalized_rows staging_inq2025_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inq2025_normalized_rows_update_developer_only ON public.staging_inq2025_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2022b_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2022b_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inv2022b_normalized_rows staging_inv2022b_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2022b_normalized_rows_delete_developer_only ON public.staging_inv2022b_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2022b_normalized_rows staging_inv2022b_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2022b_normalized_rows_insert_developer_only ON public.staging_inv2022b_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2022b_normalized_rows staging_inv2022b_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2022b_normalized_rows_select_developer_only ON public.staging_inv2022b_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2022b_normalized_rows staging_inv2022b_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2022b_normalized_rows_update_developer_only ON public.staging_inv2022b_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2023_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2023_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inv2023_normalized_rows staging_inv2023_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2023_normalized_rows_delete_developer_only ON public.staging_inv2023_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2023_normalized_rows staging_inv2023_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2023_normalized_rows_insert_developer_only ON public.staging_inv2023_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2023_normalized_rows staging_inv2023_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2023_normalized_rows_select_developer_only ON public.staging_inv2023_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2023_normalized_rows staging_inv2023_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2023_normalized_rows_update_developer_only ON public.staging_inv2023_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2024_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2024_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inv2024_normalized_rows staging_inv2024_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2024_normalized_rows_delete_developer_only ON public.staging_inv2024_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2024_normalized_rows staging_inv2024_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2024_normalized_rows_insert_developer_only ON public.staging_inv2024_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2024_normalized_rows staging_inv2024_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2024_normalized_rows_select_developer_only ON public.staging_inv2024_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2024_normalized_rows staging_inv2024_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2024_normalized_rows_update_developer_only ON public.staging_inv2024_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2025_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_inv2025_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_inv2025_normalized_rows staging_inv2025_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2025_normalized_rows_delete_developer_only ON public.staging_inv2025_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2025_normalized_rows staging_inv2025_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2025_normalized_rows_insert_developer_only ON public.staging_inv2025_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_inv2025_normalized_rows staging_inv2025_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2025_normalized_rows_select_developer_only ON public.staging_inv2025_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_inv2025_normalized_rows staging_inv2025_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_inv2025_normalized_rows_update_developer_only ON public.staging_inv2025_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_pe2024_normalized_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staging_pe2024_normalized_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: staging_pe2024_normalized_rows staging_pe2024_normalized_rows_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_pe2024_normalized_rows_delete_developer_only ON public.staging_pe2024_normalized_rows FOR DELETE TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_pe2024_normalized_rows staging_pe2024_normalized_rows_insert_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_pe2024_normalized_rows_insert_developer_only ON public.staging_pe2024_normalized_rows FOR INSERT TO authenticated WITH CHECK (public.can_manage_system_internal());


--
-- Name: staging_pe2024_normalized_rows staging_pe2024_normalized_rows_select_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_pe2024_normalized_rows_select_developer_only ON public.staging_pe2024_normalized_rows FOR SELECT TO authenticated USING (public.can_manage_system_internal());


--
-- Name: staging_pe2024_normalized_rows staging_pe2024_normalized_rows_update_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staging_pe2024_normalized_rows_update_developer_only ON public.staging_pe2024_normalized_rows FOR UPDATE TO authenticated USING (public.can_manage_system_internal()) WITH CHECK (public.can_manage_system_internal());


--
-- Name: user_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles user_roles_delete_by_allowed_role_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_roles_delete_by_allowed_role_managers ON public.user_roles FOR DELETE TO authenticated USING ((public.can_manage_users() AND public.can_assign_role(( SELECT r.code
   FROM public.roles r
  WHERE (r.id = user_roles.role_id)))));


--
-- Name: user_roles user_roles_insert_by_allowed_role_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_roles_insert_by_allowed_role_managers ON public.user_roles FOR INSERT TO authenticated WITH CHECK ((public.can_manage_users() AND public.can_assign_role(( SELECT r.code
   FROM public.roles r
  WHERE (r.id = user_roles.role_id)))));


--
-- Name: user_roles user_roles_select_self_or_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_roles_select_self_or_managers ON public.user_roles FOR SELECT TO authenticated USING ((public.can_manage_users() OR (user_id = public.current_app_user_id())));


--
-- Name: user_roles user_roles_update_by_allowed_role_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_roles_update_by_allowed_role_managers ON public.user_roles FOR UPDATE TO authenticated USING ((public.can_manage_users() AND public.can_assign_role(( SELECT r.code
   FROM public.roles r
  WHERE (r.id = user_roles.role_id))))) WITH CHECK ((public.can_manage_users() AND public.can_assign_role(( SELECT r.code
   FROM public.roles r
  WHERE (r.id = user_roles.role_id)))));


--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_delete_developer_only ON public.users FOR DELETE TO authenticated USING (public.has_app_role('DEVELOPER'::text));


--
-- Name: users users_insert_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_insert_by_user_managers ON public.users FOR INSERT TO authenticated WITH CHECK (public.can_manage_users());


--
-- Name: users users_select_self_or_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select_self_or_managers ON public.users FOR SELECT TO authenticated USING ((public.can_manage_users() OR (id = public.current_app_user_id())));


--
-- Name: users users_update_by_user_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_update_by_user_managers ON public.users FOR UPDATE TO authenticated USING (public.can_manage_users()) WITH CHECK (public.can_manage_users());


--
-- Name: violations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.violations ENABLE ROW LEVEL SECURITY;

--
-- Name: violations violations_delete_developer_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY violations_delete_developer_only ON public.violations FOR DELETE TO authenticated USING (public.can_delete_seed_data());


--
-- Name: violations violations_insert_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY violations_insert_by_seed_managers ON public.violations FOR INSERT TO authenticated WITH CHECK (public.can_manage_seed_data());


--
-- Name: violations violations_select_for_app_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY violations_select_for_app_users ON public.violations FOR SELECT TO authenticated USING (public.is_authenticated_app_user());


--
-- Name: violations violations_update_by_seed_managers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY violations_update_by_seed_managers ON public.violations FOR UPDATE TO authenticated USING (public.can_manage_seed_data()) WITH CHECK (public.can_manage_seed_data());


--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict qnRWCXRPfxj7eilPJJnMSoFcVMsbrDKvaGZAA2xeOb6EkAUYrHuLeaxq6f31eHf

