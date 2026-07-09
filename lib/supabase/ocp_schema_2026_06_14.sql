--
-- PostgreSQL database dump
--

\restrict t7blyZqqpaxPa9pImFQQnS3OZKJcXpLd2GvRFQn9O77jrdsEtcm0OE8pH0btyb4

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
    'in',
    'like',
    'ilike',
    'is',
    'match',
    'imatch',
    'isdistinct'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text,
	negate boolean
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
-- Name: create_new_docket_entry(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_new_docket_entry(p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_auth_uid uuid := auth.uid(); v_user_id bigint; v_case_id bigint; v_item jsonb; v_sub jsonb; v_contact_id bigint; v_audit_metadata jsonb;
  v_docket_type_id bigint := (p_payload->>'docketTypeId')::bigint; v_docket_year int := (p_payload->>'docketYear')::int; v_date_received date := (p_payload->>'dateReceived')::date; v_initial_status_id bigint := (p_payload->>'initialStatusId')::bigint;
  v_case_classification_id bigint := nullif(p_payload->>'caseClassificationId','')::bigint; v_region_code text := nullif(btrim(p_payload->>'regionCode'), ''); v_month_code text; v_docket_number int; v_display text; v_dt_prefix text;
  v_person_id bigint; v_org_id bigint; v_name text; v_cp_id bigint; v_address_id bigint; v_violation_id bigint; v_received_event_type_id bigint; v_raffled_event_type_id bigint; v_event_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_assignment_event_id bigint; v_assignment_id bigint;
  v_pending_status_id bigint; v_for_raffle_stage_id bigint; v_case_raffled_stage_id bigint; v_initial_stage_id bigint; v_status_date date := COALESCE(v_date_received, CURRENT_DATE);
  v_assigned_prosecutor_id bigint := CASE WHEN COALESCE((p_payload->>'caseAlsoRaffled')::boolean,false) THEN nullif(p_payload->>'assignedProsecutorId','')::bigint ELSE NULL END; v_assignment_date date := v_date_received; v_assignment_remarks text := CASE WHEN p_payload ? 'assignmentRemarks' THEN nullif(btrim(p_payload->>'assignmentRemarks'),'') ELSE 'Assigned during manual docket creation' END;
  v_case_note_text text := nullif(btrim(p_payload->>'notes'),'');
  v_case_received_description text := COALESCE(nullif(btrim(p_payload->>'caseReceivedDescription'),''), 'Case received on ' || to_char(v_date_received, 'FMMM/FMDD/YYYY'));
  v_seen_violation_ids bigint[] := '{}'; v_created_persons int := 0; v_reused_persons int := 0; v_created_addresses int := 0; v_reused_addresses int := 0; v_created_violations int := 0; v_reused_violations int := 0; v_participant_count int := 0; v_violation_count int := 0;
BEGIN
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Authenticated Supabase user is required for docket creation'; END IF;
  SELECT id INTO v_user_id FROM public.users WHERE auth_user_id = v_auth_uid AND is_active IS TRUE LIMIT 1;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authenticated user % is not mapped to an active public.users row', v_auth_uid; END IF;
  IF v_docket_type_id IS NULL OR v_docket_year IS NULL OR v_date_received IS NULL THEN RAISE EXCEPTION 'Missing required case fields'; END IF;
  IF jsonb_array_length(COALESCE(p_payload->'participants','[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'At least one participant is required'; END IF;
  IF jsonb_array_length(COALESCE(p_payload->'violations','[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'At least one violation is required'; END IF;
  SELECT prefix INTO v_dt_prefix FROM public.docket_types WHERE id = v_docket_type_id AND is_active IS TRUE; IF v_dt_prefix IS NULL THEN RAISE EXCEPTION 'Invalid docket type id'; END IF;
  IF v_initial_status_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.case_statuses WHERE id = v_initial_status_id) THEN RAISE EXCEPTION 'Invalid initial status id'; END IF;
  IF v_case_classification_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.case_classifications WHERE id = v_case_classification_id) THEN RAISE EXCEPTION 'Invalid case classification id %', v_case_classification_id; END IF;
  IF COALESCE((p_payload->>'caseAlsoRaffled')::boolean,false) AND v_assigned_prosecutor_id IS NULL THEN RAISE EXCEPTION 'assignedProsecutorId is required when caseAlsoRaffled is true'; END IF;
  IF v_assigned_prosecutor_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = v_assigned_prosecutor_id AND is_active IS TRUE) THEN RAISE EXCEPTION 'Invalid assigned prosecutor id %', v_assigned_prosecutor_id; END IF;
  SELECT id INTO v_received_event_type_id FROM public.case_event_types WHERE is_active IS TRUE AND code = 'CASE_RECEIVED' LIMIT 1; IF v_received_event_type_id IS NULL THEN RAISE EXCEPTION 'No active CASE_RECEIVED case event type'; END IF;
  IF v_assigned_prosecutor_id IS NOT NULL THEN SELECT id INTO v_raffled_event_type_id FROM public.case_event_types WHERE is_active IS TRUE AND code = 'CASE_RAFFLED' LIMIT 1; IF v_raffled_event_type_id IS NULL THEN RAISE EXCEPTION 'No active CASE_RAFFLED case event type'; END IF; END IF;
  SELECT id INTO v_pending_status_id FROM public.case_statuses WHERE code = 'PENDING' AND is_active IS TRUE LIMIT 1; IF v_pending_status_id IS NULL THEN RAISE EXCEPTION 'No active PENDING case status'; END IF;
  SELECT id INTO v_for_raffle_stage_id FROM public.case_stages WHERE code = 'FOR_RAFFLE' AND is_active IS TRUE LIMIT 1; IF v_for_raffle_stage_id IS NULL THEN RAISE EXCEPTION 'No active FOR_RAFFLE case stage'; END IF;
  SELECT id INTO v_case_raffled_stage_id FROM public.case_stages WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE LIMIT 1; IF v_case_raffled_stage_id IS NULL THEN RAISE EXCEPTION 'No active CASE_RAFFLED case stage'; END IF;
  v_initial_stage_id := CASE WHEN v_assigned_prosecutor_id IS NOT NULL THEN v_case_raffled_stage_id ELSE v_for_raffle_stage_id END;

  PERFORM pg_advisory_xact_lock(v_docket_type_id::int, v_docket_year);
  SELECT COALESCE(MAX(docket_number),0)+1 INTO v_docket_number FROM public.cases WHERE docket_type_id = v_docket_type_id AND docket_year = v_docket_year;
  v_month_code := upper(COALESCE(nullif(btrim(p_payload->>'docketMonthCode'),''), chr(64 + extract(month from v_date_received)::int))); IF v_month_code !~ '^[A-L]$' THEN RAISE EXCEPTION 'Invalid docket month code %', v_month_code; END IF; v_display := concat_ws('-', v_region_code, v_dt_prefix, right(v_docket_year::text,2)||v_month_code, lpad(v_docket_number::text,6,'0'));
  INSERT INTO public.cases(docket_type_id,docket_year,docket_number,date_received,created_by_user_id,updated_by_user_id,is_archived,region_code,docket_month_code,case_classification_id) VALUES (v_docket_type_id,v_docket_year,v_docket_number,v_date_received,v_user_id,v_user_id,false,v_region_code,v_month_code,v_case_classification_id) RETURNING id INTO v_case_id;
  INSERT INTO public.case_private_details(case_id,source,remarks,is_summary_procedure,summary_text,current_status_id,current_status_date,current_case_status_id,current_case_status_date,current_case_stage_id,current_case_stage_date) VALUES (v_case_id,'MANUAL_ENTRY',nullif(btrim(p_payload->>'remarks'),''),COALESCE((p_payload->>'isSummaryProcedure')::boolean,false),nullif(btrim(p_payload->>'summaryText'),''),v_pending_status_id,v_status_date,v_pending_status_id,v_status_date,v_initial_stage_id,v_status_date);
  INSERT INTO public.docket_number_history(case_id,docket_type_id,docket_year,docket_number,docket_display_number,event_type,changed_by_user_id,changed_at,reason) VALUES (v_case_id,v_docket_type_id,v_docket_year,v_docket_number,v_display,'ASSIGNED',v_user_id,now(),'Manual docket creation');
  IF v_case_note_text IS NOT NULL THEN INSERT INTO public.notes(case_id,created_by_user_id,note_text,is_private) VALUES (v_case_id,v_user_id,v_case_note_text,false); END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'participants') LOOP
    IF (nullif(v_item->>'existingPersonId','') IS NOT NULL OR v_item ? 'newPerson') AND (nullif(v_item->>'existingOrganizationId','') IS NOT NULL OR v_item ? 'newOrganization') THEN RAISE EXCEPTION 'Participant cannot contain both person and organization identity'; END IF;
    IF NOT (nullif(v_item->>'existingPersonId','') IS NOT NULL OR v_item ? 'newPerson' OR nullif(v_item->>'existingOrganizationId','') IS NOT NULL OR v_item ? 'newOrganization') THEN RAISE EXCEPTION 'Participant must contain exactly one person or organization identity'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.participant_roles WHERE id = (v_item->>'roleId')::bigint) THEN RAISE EXCEPTION 'Invalid participant role'; END IF;
    v_person_id := NULL; v_org_id := NULL;
    IF nullif(v_item->>'existingOrganizationId','') IS NOT NULL OR v_item ? 'newOrganization' THEN
      IF nullif(v_item->>'existingOrganizationId','') IS NOT NULL THEN SELECT id, organization_name INTO v_org_id, v_name FROM public.organizations WHERE id=(v_item->>'existingOrganizationId')::bigint; IF v_org_id IS NULL THEN RAISE EXCEPTION 'Existing organization not found'; END IF;
      ELSE v_name := nullif(btrim(v_item#>>'{newOrganization,organizationName}'),''); IF v_name IS NULL THEN RAISE EXCEPTION 'Organization name is required'; END IF; INSERT INTO public.organizations(organization_name,contact_person,contact_number,email,details_jsonb,created_by_user_id,updated_by_user_id) VALUES (v_name,nullif(btrim(v_item#>>'{newOrganization,contactPerson}'),''),nullif(btrim(v_item#>>'{newOrganization,contactNumber}'),''),nullif(btrim(v_item#>>'{newOrganization,email}'),''),COALESCE(NULLIF(v_item#>'{newOrganization,detailsJsonb}', 'null'::jsonb), '{}'::jsonb),v_user_id,v_user_id) RETURNING id INTO v_org_id; END IF;
      FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'aliases','[]'::jsonb)) LOOP IF nullif(btrim(v_sub->>'aliasName'),'') IS NOT NULL THEN UPDATE public.organization_aliases oa SET is_active = TRUE, updated_at = now() WHERE oa.organization_id = v_org_id AND lower(btrim(oa.alias_name)) = lower(btrim(v_sub->>'aliasName')) AND oa.is_active IS FALSE; INSERT INTO public.organization_aliases(organization_id,alias_name,source) SELECT v_org_id,btrim(v_sub->>'aliasName'),'MANUAL_ENTRY' WHERE NOT EXISTS (SELECT 1 FROM public.organization_aliases oa WHERE oa.organization_id = v_org_id AND lower(btrim(oa.alias_name)) = lower(btrim(v_sub->>'aliasName'))); END IF; END LOOP;
      PERFORM public.upsert_clearance_possible_tokens_for_organization(v_org_id); PERFORM public.upsert_clearance_phonetic_tokens_for_organization(v_org_id);
    ELSE
      IF nullif(v_item->>'existingPersonId','') IS NOT NULL THEN SELECT id, full_name INTO v_person_id, v_name FROM public.persons WHERE id=(v_item->>'existingPersonId')::bigint; IF v_person_id IS NULL THEN RAISE EXCEPTION 'Existing person not found'; END IF; v_reused_persons := v_reused_persons+1;
      ELSE v_name := regexp_replace(concat_ws(' ', nullif(btrim(v_item#>>'{newPerson,firstName}'),''), CASE WHEN COALESCE((v_item#>>'{newPerson,noMiddleName}')::boolean,false) THEN 'NMN' ELSE nullif(btrim(v_item#>>'{newPerson,middleName}'),'') END, nullif(btrim(v_item#>>'{newPerson,lastName}'),''), nullif(btrim(v_item#>>'{newPerson,suffix}'),'')), '\s+', ' ', 'g'); IF v_name = '' THEN RAISE EXCEPTION 'New participant full-name preview cannot be empty'; END IF; INSERT INTO public.persons(first_name,middle_name,last_name,suffix,full_name,gender,birth_date,notes,person_descriptor) VALUES (nullif(btrim(v_item#>>'{newPerson,firstName}'),''),CASE WHEN COALESCE((v_item#>>'{newPerson,noMiddleName}')::boolean,false) THEN 'NMN' ELSE nullif(btrim(v_item#>>'{newPerson,middleName}'),'') END,nullif(btrim(v_item#>>'{newPerson,lastName}'),''),nullif(btrim(v_item#>>'{newPerson,suffix}'),''),v_name,nullif(btrim(v_item#>>'{newPerson,gender}'),''),nullif(v_item#>>'{newPerson,birthDate}','')::date,nullif(btrim(v_item#>>'{newPerson,notes}'),''),nullif(btrim(v_item#>>'{newPerson,personDescriptor}'),'')) RETURNING id INTO v_person_id; v_created_persons := v_created_persons+1; END IF;
      FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'aliases','[]'::jsonb)) LOOP IF nullif(btrim(v_sub->>'aliasName'),'') IS NOT NULL THEN UPDATE public.person_aliases pa SET is_active = TRUE, updated_at = now() WHERE pa.person_id = v_person_id AND lower(btrim(pa.alias_name)) = lower(btrim(v_sub->>'aliasName')) AND pa.is_active IS FALSE; INSERT INTO public.person_aliases(person_id,alias_name,alias_type,source) SELECT v_person_id,btrim(v_sub->>'aliasName'),'AKA','MANUAL_ENTRY' WHERE NOT EXISTS (SELECT 1 FROM public.person_aliases pa WHERE pa.person_id = v_person_id AND lower(btrim(pa.alias_name)) = lower(btrim(v_sub->>'aliasName'))); END IF; END LOOP;
      PERFORM public.upsert_clearance_possible_tokens_for_person(v_person_id); PERFORM public.upsert_clearance_phonetic_tokens_for_person(v_person_id);
    END IF;
    FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'addresses','[]'::jsonb)) LOOP
      IF nullif(v_sub->>'existingAddressId','') IS NOT NULL THEN SELECT id INTO v_address_id FROM public.addresses WHERE id=(v_sub->>'existingAddressId')::bigint; IF v_address_id IS NULL THEN RAISE EXCEPTION 'Existing address not found'; END IF; v_reused_addresses:=v_reused_addresses+1; ELSE INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country) VALUES (nullif(btrim(v_sub#>>'{newAddress,line1}'),''),nullif(btrim(v_sub#>>'{newAddress,line2}'),''),nullif(btrim(v_sub#>>'{newAddress,barangay}'),''),nullif(btrim(v_sub#>>'{newAddress,city}'),''),nullif(btrim(v_sub#>>'{newAddress,province}'),''),nullif(btrim(v_sub#>>'{newAddress,region}'),''),nullif(btrim(v_sub#>>'{newAddress,zipCode}'),''),COALESCE(nullif(btrim(v_sub#>>'{newAddress,country}'),''),'Philippines')) RETURNING id INTO v_address_id; v_created_addresses:=v_created_addresses+1; END IF;
      IF v_org_id IS NOT NULL THEN INSERT INTO public.organization_addresses(organization_id,address_id,address_type_id,is_primary,remarks) VALUES (v_org_id,v_address_id,(v_sub->>'addressTypeId')::bigint,COALESCE((v_sub->>'isPrimary')::boolean,false),nullif(btrim(v_sub->>'remarks'),'')) ON CONFLICT (organization_id,address_id,address_type_id) DO UPDATE SET is_primary = EXCLUDED.is_primary, remarks = COALESCE(EXCLUDED.remarks, public.organization_addresses.remarks);
      ELSE INSERT INTO public.person_addresses(person_id,address_id,address_type_id,is_primary,remarks) VALUES (v_person_id,v_address_id,(v_sub->>'addressTypeId')::bigint,COALESCE((v_sub->>'isPrimary')::boolean,false),nullif(btrim(v_sub->>'remarks'),'')) ON CONFLICT (person_id,address_id,address_type_id) DO UPDATE SET is_primary = EXCLUDED.is_primary, remarks = COALESCE(EXCLUDED.remarks, public.person_addresses.remarks); END IF;
    END LOOP;
    INSERT INTO public.case_participants(case_id,person_id,organization_id,role_id,participant_order,participant_kind,display_name_snapshot) VALUES (v_case_id,v_person_id,v_org_id,(v_item->>'roleId')::bigint,COALESCE((v_item->>'participantOrder')::int,v_participant_count+1),CASE WHEN v_org_id IS NULL THEN 'PERSON' ELSE 'ORGANIZATION' END,v_name) RETURNING id INTO v_cp_id; v_participant_count:=v_participant_count+1;
    FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'contactInformations','[]'::jsonb)) LOOP
      IF nullif(btrim(v_sub->>'contactValue'),'') IS NOT NULL THEN
        INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary, remarks)
        VALUES (COALESCE(nullif(upper(btrim(v_sub->>'contactType')),''),'PHONE'), btrim(v_sub->>'contactValue'), nullif(btrim(v_sub->>'label'),''), COALESCE((v_sub->>'isPrimary')::boolean,false), nullif(btrim(v_sub->>'remarks'),''))
        RETURNING id INTO v_contact_id;
        INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_cp_id, v_contact_id);
      END IF;
    END LOOP;
    IF nullif(btrim(v_item->>'contactNumber'),'') IS NOT NULL THEN INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary) VALUES ('PHONE', btrim(v_item->>'contactNumber'), 'Primary phone', true) RETURNING id INTO v_contact_id; INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_cp_id, v_contact_id); END IF;
    IF nullif(btrim(v_item->>'email'),'') IS NOT NULL THEN INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary) VALUES ('EMAIL', btrim(v_item->>'email'), 'Primary email', false) RETURNING id INTO v_contact_id; INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_cp_id, v_contact_id); END IF;
    IF nullif(btrim(v_item->>'remarks'),'') IS NOT NULL OR nullif(btrim(v_item->>'sourceDetail'),'') IS NOT NULL THEN INSERT INTO public.case_participant_private_details(case_participant_id,case_id,source,remarks,source_detail) VALUES (v_cp_id,v_case_id,'MANUAL_ENTRY',nullif(btrim(v_item->>'remarks'),''),nullif(btrim(v_item->>'sourceDetail'),'')); END IF;
    IF v_person_id IS NOT NULL AND v_item ? 'attributes' AND v_item->'attributes' <> 'null'::jsonb THEN INSERT INTO public.case_participant_attributes(case_participant_id,age_text,age_years,age_basis_date,age_source,gender_text,gender_normalized,minor_text,is_minor_at_case,senior_text,is_senior_at_case,pwd_text,is_pwd_at_case,notes,created_by_user_id,updated_by_user_id) VALUES (v_cp_id,nullif(btrim(v_item#>>'{attributes,ageText}'),''),nullif(v_item#>>'{attributes,ageYears}','')::int,v_date_received,'MANUAL_ENTRY',nullif(btrim(v_item#>>'{attributes,genderText}'),''),nullif(btrim(v_item#>>'{attributes,genderNormalized}'),''),nullif(btrim(v_item#>>'{attributes,minorText}'),''),nullif(v_item#>>'{attributes,isMinorAtCase}','')::boolean,nullif(btrim(v_item#>>'{attributes,seniorText}'),''),nullif(v_item#>>'{attributes,isSeniorAtCase}','')::boolean,nullif(btrim(v_item#>>'{attributes,pwdText}'),''),nullif(v_item#>>'{attributes,isPwdAtCase}','')::boolean,nullif(btrim(v_item#>>'{attributes,notes}'),''),v_user_id,v_user_id); END IF;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(CASE WHEN p_payload ? 'placesOfCommission' AND jsonb_typeof(p_payload->'placesOfCommission') = 'array' THEN p_payload->'placesOfCommission' WHEN p_payload ? 'placeOfCommission' AND p_payload->'placeOfCommission' <> 'null'::jsonb THEN jsonb_build_array(p_payload->'placeOfCommission') ELSE COALESCE(p_payload->'addresses','[]'::jsonb) END) LOOP
    IF nullif(v_item->>'existingAddressId','') IS NOT NULL THEN SELECT id INTO v_address_id FROM public.addresses WHERE id=(v_item->>'existingAddressId')::bigint; v_reused_addresses:=v_reused_addresses+1; ELSE INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country) VALUES (nullif(btrim(v_item#>>'{newAddress,line1}'),''),nullif(btrim(v_item#>>'{newAddress,line2}'),''),nullif(btrim(v_item#>>'{newAddress,barangay}'),''),nullif(btrim(v_item#>>'{newAddress,city}'),''),nullif(btrim(v_item#>>'{newAddress,province}'),''),nullif(btrim(v_item#>>'{newAddress,region}'),''),nullif(btrim(v_item#>>'{newAddress,zipCode}'),''),COALESCE(nullif(btrim(v_item#>>'{newAddress,country}'),''),'Philippines')) RETURNING id INTO v_address_id; v_created_addresses:=v_created_addresses+1; END IF;
    INSERT INTO public.case_addresses(case_id,address_id,address_type_id,is_primary,remarks) VALUES (v_case_id,v_address_id,(v_item->>'addressTypeId')::bigint,COALESCE((v_item->>'isPrimary')::boolean,true),nullif(btrim(v_item->>'remarks'),''));
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'violations') LOOP
    v_violation_id := COALESCE(NULLIF(v_item->>'existingViolationId',''), NULLIF(v_item->>'violationId',''))::bigint;
    IF v_violation_id IS NULL THEN INSERT INTO public.violations(title,reference_code,short_label,description,law_reference,created_by_user_id,is_active,canonical_title) VALUES (btrim(v_item#>>'{newViolation,title}'),nullif(btrim(v_item#>>'{newViolation,referenceCode}'),''),nullif(btrim(v_item#>>'{newViolation,shortLabel}'),''),nullif(btrim(v_item#>>'{newViolation,description}'),''),nullif(btrim(v_item#>>'{newViolation,lawReference}'),''),v_user_id,true,regexp_replace(lower(btrim(v_item#>>'{newViolation,title}')), '\s+', ' ', 'g')) RETURNING id INTO v_violation_id; v_created_violations:=v_created_violations+1; ELSE v_reused_violations:=v_reused_violations+1; END IF;
    IF v_violation_id = ANY(v_seen_violation_ids) THEN RAISE EXCEPTION 'Duplicate violation id % in payload', v_violation_id; END IF; v_seen_violation_ids:=array_append(v_seen_violation_ids,v_violation_id);
    INSERT INTO public.case_violations(case_id,violation_id,violation_order,raw_violation_text) VALUES (v_case_id,v_violation_id,COALESCE((v_item->>'violationOrder')::int,v_violation_count+1),nullif(btrim(v_item->>'rawViolationText'),'')); v_violation_count:=v_violation_count+1;
  END LOOP;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_order,title,description,status_id,case_status_id,case_stage_id,source,source_table,created_by_user_id,updated_by_user_id) VALUES (v_case_id,v_received_event_type_id,v_status_date,1,'Case received',v_case_received_description,v_pending_status_id,v_pending_status_id,v_initial_stage_id,'MANUAL_ENTRY','case_status_history',v_user_id,v_user_id) RETURNING id INTO v_event_id;
  INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (v_case_id,NULL,v_pending_status_id,v_user_id,now(),v_status_date,v_case_received_description,v_event_id) RETURNING id INTO v_status_history_id;
  INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (v_case_id,NULL,v_initial_stage_id,v_user_id,now(),v_status_date,v_case_received_description,v_event_id) RETURNING id INTO v_stage_history_id;
  UPDATE public.case_events SET source_id = v_status_history_id WHERE id = v_event_id;
  IF v_assigned_prosecutor_id IS NOT NULL THEN INSERT INTO public.case_assignments(case_id,prosecutor_id,assigned_by_user_id,assigned_at,remarks) VALUES (v_case_id,v_assigned_prosecutor_id,v_user_id,v_assignment_date::timestamp with time zone,v_assignment_remarks) RETURNING id INTO v_assignment_id; INSERT INTO public.case_events(case_id,event_type_id,event_date,event_order,title,description,status_id,case_status_id,case_stage_id,prosecutor_id,source,source_table,source_id,created_by_user_id,updated_by_user_id) VALUES (v_case_id,v_raffled_event_type_id,v_status_date,2,'Case raffled',v_assignment_remarks,v_pending_status_id,v_pending_status_id,v_case_raffled_stage_id,v_assigned_prosecutor_id,'MANUAL_ENTRY','case_assignments',v_assignment_id,v_user_id,v_user_id) RETURNING id INTO v_assignment_event_id; UPDATE public.case_assignments SET case_event_id = v_assignment_event_id WHERE id = v_assignment_id; END IF;

  v_audit_metadata := jsonb_build_object(
    'payload', p_payload,
    'case_status_stage_split', jsonb_build_object(
      'current_case_status_id', v_pending_status_id,
      'current_case_stage_id', v_initial_stage_id,
      'case_received_event_id', v_event_id,
      'case_received_event_case_status_id', v_pending_status_id,
      'case_received_event_case_stage_id', v_initial_stage_id,
      'assignment_event_id', v_assignment_event_id,
      'assignment_event_case_status_id', CASE WHEN v_assignment_event_id IS NULL THEN NULL ELSE v_pending_status_id END,
      'assignment_event_case_stage_id', CASE WHEN v_assignment_event_id IS NULL THEN NULL ELSE v_case_raffled_stage_id END,
      'case_stage_history_id', v_stage_history_id
    ),
    'inserted', jsonb_build_object(
      'cases', jsonb_build_object('id', v_case_id, 'columns', jsonb_build_array('docket_type_id','docket_year','docket_number','date_received','created_by_user_id','updated_by_user_id','is_archived','region_code','docket_month_code','case_classification_id')),
      'case_private_details', jsonb_build_object('columns', jsonb_build_array('case_id','source','remarks','is_summary_procedure','summary_text','current_status_id','current_status_date','current_case_status_id','current_case_status_date','current_case_stage_id','current_case_stage_date')),
      'notes', CASE WHEN v_case_note_text IS NULL THEN NULL ELSE jsonb_build_object('columns', jsonb_build_array('case_id','created_by_user_id','note_text','is_private')) END,
      'docket_number_history', jsonb_build_object('columns', jsonb_build_array('case_id','docket_type_id','docket_year','docket_number','docket_display_number','event_type','changed_by_user_id','changed_at','reason')),
      'case_participants', jsonb_build_object('count', v_participant_count, 'columns', jsonb_build_array('case_id','person_id','organization_id','role_id','participant_order','participant_kind','display_name_snapshot')),
      'case_addresses', jsonb_build_object('columns', jsonb_build_array('case_id','address_id','address_type_id','is_primary','remarks')),
      'case_violations', jsonb_build_object('count', v_violation_count, 'columns', jsonb_build_array('case_id','violation_id','violation_order','raw_violation_text')),
      'case_events', jsonb_build_object('columns', jsonb_build_array('case_id','event_type_id','event_date','event_order','title','description','status_id','case_status_id','case_stage_id','prosecutor_id','source','source_table','source_id','created_by_user_id','updated_by_user_id')),
      'case_status_history', jsonb_build_object('id', v_status_history_id, 'columns', jsonb_build_array('case_id','from_status_id','to_status_id','changed_by_user_id','changed_at','status_date','remarks','case_event_id')),
      'case_stage_history', jsonb_build_object('id', v_stage_history_id, 'columns', jsonb_build_array('case_id','from_stage_id','to_stage_id','changed_by_user_id','changed_at','stage_date','remarks','case_event_id')),
      'case_assignments', CASE WHEN v_assignment_id IS NULL THEN NULL ELSE jsonb_build_object('id', v_assignment_id, 'columns', jsonb_build_array('case_id','prosecutor_id','assigned_by_user_id','assigned_at','remarks','case_event_id')) END,
      'persons', jsonb_build_object('createdCount', v_created_persons, 'reusedCount', v_reused_persons),
      'addresses', jsonb_build_object('createdCount', v_created_addresses, 'reusedCount', v_reused_addresses),
      'violations', jsonb_build_object('createdCount', v_created_violations, 'reusedCount', v_reused_violations),
      'contact_informations', jsonb_build_object('columns', jsonb_build_array('contact_type','contact_value','label','is_primary','remarks')),
      'participant_contact_informations', jsonb_build_object('columns', jsonb_build_array('case_participant_id','contact_information_id'))
    )
  );

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, new_data)
  VALUES (v_user_id, 'CREATE_DOCKET', 'cases', v_case_id, v_case_id, 'user[' || v_user_id::text || '] created the new docket ' || v_display, v_audit_metadata, v_audit_metadata);

  RETURN jsonb_build_object('caseId',v_case_id,'docketTypeId',v_docket_type_id,'docketYear',v_docket_year,'docketNumber',v_docket_number,'docketMonthCode',v_month_code,'docketDisplayNumber',v_display,'createdPersonCount',v_created_persons,'reusedPersonCount',v_reused_persons,'createdAddressCount',v_created_addresses,'reusedAddressCount',v_reused_addresses,'createdViolationCount',v_created_violations,'reusedViolationCount',v_reused_violations,'participantCount',v_participant_count,'violationCount',v_violation_count);
END;
$_$;


--
-- Name: FUNCTION create_new_docket_entry(p_payload jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_new_docket_entry(p_payload jsonb) IS 'Creates a docket entry and supports multiple places of commission via placesOfCommission[] (legacy placeOfCommission still accepted).';


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
-- Name: edit_case_event(bigint, date, text, text, jsonb, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.edit_case_event(p_case_event_id bigint, p_event_date date, p_title text, p_description text, p_details_jsonb jsonb DEFAULT NULL::jsonb, p_edit_reason text DEFAULT NULL::text, p_user_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_case_id bigint;
BEGIN
  IF nullif(trim(p_edit_reason), '') IS NULL THEN
    RAISE EXCEPTION 'Edit reason is required';
  END IF;

  SELECT to_jsonb(ce), ce.case_id
  INTO v_old, v_case_id
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id
    AND ce.is_voided = false;

  IF v_old IS NULL THEN
    RAISE EXCEPTION 'Active case event % not found', p_case_event_id;
  END IF;

  UPDATE public.case_events
  SET event_date = p_event_date,
      title = nullif(trim(p_title), ''),
      description = nullif(trim(p_description), ''),
      details_jsonb = COALESCE(p_details_jsonb, details_jsonb, '{}'::jsonb),
      updated_by_user_id = p_user_id,
      updated_at = now()
  WHERE id = p_case_event_id;

  SELECT to_jsonb(ce)
  INTO v_new
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id;

  INSERT INTO public.audit_logs (
    actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata
  )
  VALUES (
    p_user_id, 'case_events', p_case_event_id, 'EDIT_CASE_EVENT', v_old, v_new, v_case_id,
    'Edited case timeline activity', jsonb_build_object('reason', p_edit_reason)
  );

  RETURN p_case_event_id;
END;
$$;


--
-- Name: edit_case_overview_section(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.edit_case_overview_section(p_payload jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_section text := lower(btrim(p_payload->>'section'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_old jsonb;
  v_new jsonb;
  v_event_type_id bigint;
  v_event_id bigint;
  v_assignment_id bigint;
  v_status_history_id bigint;
  v_old_assignment_id bigint;
  v_old_prosecutor_id bigint;
  v_old_case_event_id bigint;
  v_linked_event_id bigint;
  v_linked_event_void text;
  v_old_prosecutor_name text;
  v_new_prosecutor_name text;
  v_staff_id bigint;
  v_assignment_action text;
  v_from_status_id bigint;
  v_to_status_id bigint;
  v_status_date date;
  v_status_remarks text;
  v_prosecutor_id bigint;
  v_assigned_at timestamptz;
  v_assignment_remarks text;
  v_old_date_received date;
  v_new_date_received date;
  v_case_received_sync text;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_section IS NULL THEN RAISE EXCEPTION 'section is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_old
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  IF v_section = 'docket_info' THEN
    SELECT date_received INTO v_old_date_received FROM public.cases WHERE id = v_case_id;
    UPDATE public.cases SET
      docket_type_id = COALESCE(nullif(p_payload#>>'{data,docketTypeId}','')::bigint, docket_type_id),
      docket_year = COALESCE(nullif(p_payload#>>'{data,docketYear}','')::int, docket_year),
      docket_number = COALESCE(nullif(p_payload#>>'{data,docketNumber}','')::int, docket_number),
      docket_month_code = COALESCE(nullif(btrim(p_payload#>>'{data,docketMonthCode}'),''), docket_month_code),
      date_received = COALESCE(nullif(p_payload#>>'{data,dateReceived}','')::date, date_received),
      updated_by_user_id = v_user_id,
      updated_at = now()
    WHERE id = v_case_id;

    SELECT date_received INTO v_new_date_received FROM public.cases WHERE id = v_case_id;
    IF v_new_date_received IS DISTINCT FROM v_old_date_received THEN
      SELECT id INTO v_event_type_id
      FROM public.case_event_types
      WHERE code = 'CASE_RECEIVED' AND is_active IS TRUE
      LIMIT 1;

      IF v_event_type_id IS NULL THEN
        v_case_received_sync := 'skipped_missing_event_type';
      ELSE
        SELECT id INTO v_event_id
        FROM public.case_events
        WHERE case_id = v_case_id
          AND event_type_id = v_event_type_id
          AND COALESCE(is_voided, false) IS FALSE
        ORDER BY event_date DESC NULLS LAST, id DESC
        LIMIT 1;

        IF v_event_id IS NOT NULL THEN
          UPDATE public.case_events
          SET event_date = v_new_date_received,
              title = COALESCE(NULLIF(title, ''), 'Case received'),
              description = COALESCE(NULLIF(description, ''), 'Case received date updated from overview edit'),
              details_jsonb = COALESCE(details_jsonb, '{}'::jsonb) || jsonb_build_object(
                'action', 'sync_case_received_from_overview',
                'old_date_received', v_old_date_received,
                'new_date_received', v_new_date_received,
                'reason', v_reason
              ),
              updated_by_user_id = v_user_id,
              updated_at = now()
          WHERE id = v_event_id;
          v_case_received_sync := 'updated_existing_event';
        ELSIF v_new_date_received IS NOT NULL THEN
          INSERT INTO public.case_events(case_id,event_type_id,event_date,title,description,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id)
          VALUES (
            v_case_id,
            v_event_type_id,
            v_new_date_received,
            'Case received',
            'Case received date updated from overview edit',
            jsonb_build_object('action', 'sync_case_received_from_overview', 'old_date_received', v_old_date_received, 'new_date_received', v_new_date_received, 'reason', v_reason),
            'MANUAL_EDIT',
            'cases',
            v_case_id,
            v_user_id,
            v_user_id
          );
          v_case_received_sync := 'created_missing_event';
        ELSE
          v_case_received_sync := 'skipped_null_date_received';
        END IF;
      END IF;
    END IF;
  ELSIF v_section = 'case_details' THEN
    UPDATE public.cases SET
      case_classification_id = nullif(p_payload#>>'{data,caseClassificationId}','')::bigint,
      updated_by_user_id = v_user_id,
      updated_at = now()
    WHERE id = v_case_id;
    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    UPDATE public.case_private_details SET
      is_summary_procedure = COALESCE(nullif(p_payload#>>'{data,isSummaryProcedure}','')::boolean, false),
      summary_text = nullif(btrim(p_payload#>>'{data,summaryText}'),''),
      remarks = nullif(btrim(p_payload#>>'{data,remarks}'),'')
    WHERE case_id = v_case_id;
  ELSIF v_section = 'status' THEN
    v_to_status_id := nullif(p_payload#>>'{data,statusId}','')::bigint;
    v_status_date := COALESCE(nullif(p_payload#>>'{data,statusDate}','')::date, current_date);
    v_status_remarks := COALESCE(nullif(btrim(p_payload#>>'{data,remarks}'),''), v_reason);
    IF v_to_status_id IS NULL THEN RAISE EXCEPTION 'statusId is required'; END IF;
    SELECT current_status_id INTO v_from_status_id FROM public.case_private_details WHERE case_id = v_case_id;
    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'STATUS_UPDATED' AND is_active IS TRUE LIMIT 1;
    IF v_event_type_id IS NULL THEN SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'CASE_RECEIVED' LIMIT 1; END IF;
    IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing case event type STATUS_UPDATED or CASE_RECEIVED'; END IF;
    INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks)
    VALUES (v_case_id,v_from_status_id,v_to_status_id,v_user_id,now(),v_status_date,v_status_remarks)
    RETURNING id INTO v_status_history_id;
    INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id)
    VALUES (
      v_case_id,
      v_event_type_id,
      v_status_date,
      now()::time,
      'Status updated',
      v_status_remarks,
      v_to_status_id,
      jsonb_build_object('from_status_id', v_from_status_id, 'to_status_id', v_to_status_id, 'status_date', v_status_date, 'remarks', v_status_remarks, 'reason', v_reason),
      'MANUAL_EDIT',
      'case_status_history',
      v_status_history_id,
      v_user_id,
      v_user_id
    ) RETURNING id INTO v_event_id;
    UPDATE public.case_status_history SET case_event_id = v_event_id WHERE id = v_status_history_id;
    UPDATE public.cases SET updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
    UPDATE public.case_private_details SET current_status_id = v_to_status_id, current_status_date = v_status_date, current_status_remarks = v_status_remarks, current_status_approved_date_raw = nullif(btrim(p_payload#>>'{data,statusApprovedDateRaw}'),'') WHERE case_id = v_case_id;
  ELSIF v_section = 'assignment' THEN
    v_prosecutor_id := nullif(p_payload#>>'{data,prosecutorId}','')::bigint;
    v_staff_id := nullif(p_payload#>>'{data,staffId}','')::bigint;
    v_assignment_action := COALESCE(nullif(btrim(p_payload#>>'{data,assignmentMode}'),''), 'reassign');
    v_assigned_at := COALESCE(nullif(p_payload#>>'{data,assignedAt}','')::timestamptz, now());
    v_assignment_remarks := COALESCE(nullif(btrim(p_payload#>>'{data,remarks}'),''), v_reason);
    IF v_assignment_action IN ('reassign', 'void_replace') AND v_prosecutor_id IS NULL THEN RAISE EXCEPTION 'prosecutorId is required'; END IF;
    IF v_assignment_action NOT IN ('reassign', 'void_replace') THEN RAISE EXCEPTION 'Unsupported assignment mode %', v_assignment_action; END IF;
    SELECT ca.id, ca.prosecutor_id, ca.case_event_id, COALESCE(p.full_name, p.short_name)
    INTO v_old_assignment_id, v_old_prosecutor_id, v_old_case_event_id, v_old_prosecutor_name
    FROM public.case_assignments ca
    LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
    WHERE ca.case_id = v_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE
    ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
    LIMIT 1;

    IF v_assignment_action IN ('reassign', 'void_replace') THEN
      SELECT COALESCE(p.full_name, p.short_name) INTO v_new_prosecutor_name
      FROM public.prosecutors p
      WHERE p.id = v_prosecutor_id;

      SELECT id INTO v_event_type_id
      FROM public.case_event_types
      WHERE code = 'CASE_RAFFLED'
        AND is_active IS TRUE
      LIMIT 1;

      IF v_event_type_id IS NULL THEN
        SELECT id INTO v_event_type_id
        FROM public.case_event_types
        WHERE code = 'CASE_ASSIGNED'
          AND is_active IS TRUE
        LIMIT 1;
      END IF;

      IF v_event_type_id IS NULL THEN
        RAISE EXCEPTION 'Missing case event type CASE_RAFFLED or CASE_ASSIGNED';
      END IF;
    END IF;

    IF v_assignment_action = 'reassign' THEN
      IF v_old_assignment_id IS NULL THEN
        RAISE EXCEPTION 'No active assignment found for case %', v_case_id;
      END IF;

      UPDATE public.case_assignments
      SET unassigned_at = COALESCE(v_assigned_at, now()),
          remarks = concat_ws(E'\n', remarks, 'Reassigned reason: ' || v_reason)
      WHERE id = v_old_assignment_id;
    ELSE
      IF v_old_assignment_id IS NULL THEN
        RAISE EXCEPTION 'No active assignment found for case %', v_case_id;
      END IF;

      UPDATE public.case_assignments
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = v_user_id,
          void_reason = v_reason,
          remarks = concat_ws(E'\n', remarks, 'Void reason: ' || v_reason)
      WHERE id = v_old_assignment_id;

      v_linked_event_id := v_old_case_event_id;
      IF v_linked_event_id IS NULL THEN
        SELECT id INTO v_linked_event_id
        FROM public.case_events
        WHERE source_table = 'case_assignments'
          AND source_id = v_old_assignment_id
        ORDER BY id DESC
        LIMIT 1;
      END IF;

      IF v_linked_event_id IS NULL THEN
        v_linked_event_void := 'skipped_no_event';
      ELSE
        UPDATE public.case_events
        SET is_voided = true,
            voided_at = now(),
            voided_by_user_id = v_user_id,
            void_reason = 'Assignment voided: ' || v_reason,
            updated_by_user_id = v_user_id,
            updated_at = now()
        WHERE id = v_linked_event_id;
        v_linked_event_void := 'voided';
      END IF;
    END IF;

    INSERT INTO public.case_assignments(case_id,prosecutor_id,staff_id,assigned_by_user_id,assigned_at,remarks)
      VALUES (v_case_id,v_prosecutor_id,v_staff_id,v_user_id,v_assigned_at,v_assignment_remarks) RETURNING id INTO v_assignment_id;
      INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,prosecutor_id,staff_id,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id)
      VALUES (
        v_case_id,
        v_event_type_id,
        v_assigned_at::date,
        v_assigned_at::time,
        CASE WHEN v_assignment_action = 'void_replace' THEN 'Case Assignment' ELSE 'Case Reassignment' END,
        v_assignment_remarks,
        v_prosecutor_id,
        v_staff_id,
        CASE WHEN v_assignment_action = 'void_replace' THEN
          jsonb_build_object('action', 'replacement_after_void', 'voided_assignment_id', v_old_assignment_id, 'voided_event_id', v_linked_event_id, 'previous_prosecutor_name', v_old_prosecutor_name, 'new_prosecutor_name', v_new_prosecutor_name, 'reason', v_reason, 'remarks', v_assignment_remarks)
        ELSE
          jsonb_build_object('action', 'reassign', 'previous_prosecutor_name', v_old_prosecutor_name, 'new_prosecutor_name', v_new_prosecutor_name, 'reason', v_reason, 'remarks', v_assignment_remarks)
        END,
        'MANUAL_EDIT',
        'case_assignments',
        v_assignment_id,
        v_user_id,
        v_user_id
      ) RETURNING id INTO v_event_id;
      UPDATE public.case_assignments SET case_event_id = v_event_id WHERE id = v_assignment_id;
      UPDATE public.cases SET updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Editing section % is not implemented yet', v_section;
  END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_new
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'EDIT_CASE_OVERVIEW_' || upper(v_section), 'cases', v_case_id, v_case_id, 'Edited case overview ' || replace(v_section, '_', ' '), jsonb_strip_nulls(jsonb_build_object('reason', v_reason, 'section', v_section, 'case_received_event_sync', v_case_received_sync, 'assignment_mode', v_assignment_action, 'linked_event_void', v_linked_event_void)), v_old, v_new);
  RETURN v_case_id;
END;
$$;


--
-- Name: format_clearance_search_results(jsonb, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.format_clearance_search_results(p_candidates jsonb, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text, is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamp with time zone, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text)
    LANGUAGE sql STABLE
    AS $$
  with input_candidates as materialized (
    select *
    from jsonb_to_recordset(coalesce(p_candidates, '[]'::jsonb)) as c(
      person_id integer, organization_id integer, participant_kind text, confidence_score integer, match_details text, match_type text, match_source text, result_group text, correction_id bigint,
      full_name text, aliases text[], is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb
    )
  ), limited_candidates as materialized (
    select distinct on (result_group, person_id, organization_id, match_source, correction_id)
      *
    from input_candidates
    where person_id is not null or organization_id is not null or correction_id is not null
    order by result_group, person_id nulls last, organization_id nulls last, match_source, correction_id nulls last, confidence_score desc
    limit least(greatest(coalesce(p_limit, 50), 1), 100) * 4
  ), joined as (
    select lc.person_id, lc.organization_id, coalesce(lc.participant_kind, case when lc.organization_id is not null then 'ORGANIZATION' else 'PERSON' end) participant_kind,
      c.id::integer case_id,
      concat_ws('-', dt.prefix, c.docket_year::text, nullif(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0')) docket_number,
      coalesce(lc.full_name, p.full_name, o.organization_name) full_name,
      coalesce(lc.aliases, pa.aliases, oa.aliases, array[]::text[]) aliases,
      coalesce(cs.display_label, cs.code, 'Pending') status,
      coalesce(c.updated_at, c.created_at, now()) last_updated,
      lc.confidence_score, lc.match_details, lc.match_type,
      coalesce(pr.display_label, pr.code, 'Participant') role_label,
      age.age_text, viol.violations,
      coalesce(lc.is_voided, false) is_voided, coalesce(lc.is_corrected, false) is_corrected, lc.replaced_by_person_id, lc.active_person_id, lc.correction_reason, lc.corrected_at, lc.corrected_by, lc.old_snapshot_json, lc.new_snapshot_json,
      coalesce(lc.result_group, 'active') result_group, coalesce(lc.match_source, lc.match_type) match_source
    from limited_candidates lc
    join public.case_participants cp on (
      (lc.correction_id is not null and cp.id = (select cpc.case_participant_id from public.case_participant_corrections cpc where cpc.id = lc.correction_id))
      or (lc.correction_id is null and ((lc.person_id is not null and cp.person_id = lc.person_id) or (lc.organization_id is not null and cp.organization_id = lc.organization_id)))
    )
    join public.cases c on c.id = cp.case_id and not coalesce(c.is_archived, false)
    join public.docket_types dt on dt.id = c.docket_type_id
    left join public.persons p on p.id = lc.person_id
    left join public.organizations o on o.id = lc.organization_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases from public.person_aliases pa where pa.person_id = lc.person_id and coalesce(pa.is_active, true)) pa on true
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases from public.organization_aliases oa where oa.organization_id = lc.organization_id and coalesce(oa.is_active, true)) oa on true
    left join public.participant_roles pr on pr.id = cp.role_id
    left join public.case_private_details cpd on cpd.case_id = c.id
    left join public.case_statuses cs on cs.id = cpd.current_status_id
    left join lateral (select cpa.age_text from public.case_participant_attributes cpa where cpa.case_participant_id = cp.id order by cpa.id desc limit 1) age on true
    left join lateral (select string_agg(v.title, ', ' order by cv.violation_order, v.title) violations from public.case_violations cv join public.violations v on v.id = cv.violation_id where cv.case_id = c.id) viol on true
  ), deduped as (
    select distinct on (result_group, person_id, organization_id, case_id, match_source)
      person_id, organization_id, participant_kind, case_id, docket_number, docket_number::text case_number, full_name, aliases, status, last_updated, confidence_score, match_details, match_type, role_label, age_text age, violations,
      is_voided, is_corrected, replaced_by_person_id, active_person_id, correction_reason, corrected_at, corrected_by, old_snapshot_json, new_snapshot_json, result_group, match_source
    from joined
    order by result_group, person_id nulls last, organization_id nulls last, case_id, match_source, confidence_score desc
  )
  select * from deduped
  order by case when result_group = 'active' then 0 else 1 end, confidence_score desc, full_name, case_id
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;


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
-- Name: manage_case_notes(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_case_notes(p_payload jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_action text := lower(btrim(p_payload->>'action'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_note jsonb := coalesce(p_payload->'note', '{}'::jsonb);
  v_note_id bigint := nullif(v_note->>'id','')::bigint;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.created_at DESC, n.id DESC), '[]'::jsonb) INTO v_old FROM public.notes n WHERE n.case_id = v_case_id;

  IF v_action = 'add' THEN
    IF nullif(btrim(v_note->>'noteText'),'') IS NULL THEN RAISE EXCEPTION 'noteText is required'; END IF;
    INSERT INTO public.notes(case_id,created_by_user_id,note_text,is_private)
    VALUES (v_case_id, v_user_id, nullif(btrim(v_note->>'noteText'),''), coalesce(nullif(v_note->>'isPrivate','')::boolean,false));
  ELSIF v_action = 'edit' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    IF EXISTS (SELECT 1 FROM public.notes WHERE id = v_note_id AND case_id = v_case_id AND is_deleted IS TRUE) THEN RAISE EXCEPTION 'Restore note before editing'; END IF;
    IF nullif(btrim(v_note->>'noteText'),'') IS NULL THEN RAISE EXCEPTION 'noteText is required'; END IF;
    UPDATE public.notes SET note_text = nullif(btrim(v_note->>'noteText'),''), is_private = coalesce(nullif(v_note->>'isPrivate','')::boolean,false), updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSIF v_action = 'remove' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.notes SET is_deleted = true, deleted_at = now(), deleted_by_user_id = v_user_id, delete_reason = v_reason, updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSIF v_action = 'restore' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.notes SET is_deleted = false, deleted_at = NULL, deleted_by_user_id = NULL, delete_reason = NULL, updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Unsupported notes action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.created_at DESC, n.id DESC), '[]'::jsonb) INTO v_new FROM public.notes n WHERE n.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_NOTES_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed case notes', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;


--
-- Name: manage_case_participants(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_case_participants(p_payload jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_action text := lower(btrim(p_payload->>'action'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_participant jsonb := coalesce(p_payload->'participant', '{}'::jsonb);
  v_case_participant_id bigint := nullif(v_participant->>'id','')::bigint;
  v_person_id bigint;
  v_new_person_id bigint;
  v_new_organization_id bigint;
  v_organization_id bigint;
  v_kind text;
  v_display text;
  v_old jsonb;
  v_new jsonb;
  v_old_snapshot jsonb;
  v_new_snapshot jsonb;
  v_alias_id bigint := nullif(v_participant->>'aliasId','')::bigint;
  v_address_relation_id bigint := nullif(v_participant->>'addressRelationId','')::bigint;
  v_address_id bigint := nullif(v_participant->>'addressId','')::bigint;
  v_contact_relation_id bigint := nullif(v_participant->>'participantContactInformationId','')::bigint;
  v_contact_id bigint := nullif(v_participant->>'contactInformationId','')::bigint;
  v_address_type_id bigint := nullif(v_participant->>'addressTypeId','')::bigint;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_case_participant_id IS NULL THEN RAISE EXCEPTION 'participant.id is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;

  SELECT cp.person_id, cp.organization_id, COALESCE(cp.participant_kind, CASE WHEN cp.organization_id IS NULL THEN 'PERSON' ELSE 'ORGANIZATION' END)
  INTO v_person_id, v_organization_id, v_kind
  FROM public.case_participants cp
  WHERE cp.id = v_case_participant_id AND cp.case_id = v_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Participant % not found for case %', v_case_participant_id, v_case_id; END IF;

  SELECT to_jsonb(vcp) INTO v_old FROM public.v_case_participants_detail vcp WHERE vcp.id = v_case_participant_id;

  IF v_action = 'edit_main_details' THEN
    IF v_kind = 'ORGANIZATION' THEN
      IF v_organization_id IS NULL THEN RAISE EXCEPTION 'Participant has no organization identity to correct'; END IF;
      v_display := nullif(btrim(v_participant->>'organizationName'), '');
      IF v_display IS NULL THEN RAISE EXCEPTION 'organizationName is required'; END IF;
      SELECT jsonb_build_object('organization', to_jsonb(o), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_old_snapshot
      FROM public.case_participants cp
      JOIN public.organizations o ON o.id = cp.organization_id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;
      INSERT INTO public.organizations(organization_name, contact_person, contact_number, email, notes, is_active, source, source_detail, legacy_source_file, legacy_source_sheet, legacy_row_number, legacy_raw_text, created_by_user_id, updated_by_user_id, details_jsonb)
      SELECT v_display, nullif(btrim(v_participant->>'contactPerson'), ''), nullif(btrim(v_participant->>'contactNumber'), ''), nullif(btrim(v_participant->>'email'), ''), o.notes, o.is_active, o.source, o.source_detail, o.legacy_source_file, o.legacy_source_sheet, o.legacy_row_number, o.legacy_raw_text, o.created_by_user_id, v_user_id, o.details_jsonb
      FROM public.organizations o WHERE o.id = v_organization_id RETURNING id INTO v_new_organization_id;
      UPDATE public.organizations SET is_voided = true, voided_at = now(), voided_by_user_id = v_user_id, void_reason = v_reason, replaced_by_organization_id = v_new_organization_id, is_active = false, updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_organization_id;
      UPDATE public.case_participants SET organization_id = v_new_organization_id, display_name_snapshot = v_display WHERE id = v_case_participant_id;
      v_organization_id := v_new_organization_id;
    ELSE
      IF v_person_id IS NULL THEN RAISE EXCEPTION 'Participant has no person identity to correct'; END IF;
      SELECT jsonb_build_object('person', to_jsonb(p), 'attributes', to_jsonb(cpa), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_old_snapshot
      FROM public.case_participants cp
      JOIN public.persons p ON p.id = cp.person_id
      LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;

      IF COALESCE((v_participant->>'useStructuredName')::boolean, false) IS TRUE THEN
        v_display := concat_ws(' ', nullif(btrim(v_participant->>'firstName'), ''), nullif(btrim(v_participant->>'middleName'), ''), nullif(btrim(v_participant->>'lastName'), ''), nullif(btrim(v_participant->>'suffix'), ''));
        IF nullif(btrim(v_display), '') IS NULL THEN RAISE EXCEPTION 'Structured name fields are required'; END IF;
        INSERT INTO public.persons(first_name,middle_name,last_name,suffix,full_name,gender,birth_date,notes,person_descriptor,age,is_minor,is_senior,is_pwd,is_active)
        SELECT nullif(btrim(v_participant->>'firstName'), ''), nullif(btrim(v_participant->>'middleName'), ''), nullif(btrim(v_participant->>'lastName'), ''), nullif(btrim(v_participant->>'suffix'), ''), btrim(v_display), nullif(btrim(v_participant->>'gender'), ''), nullif(v_participant->>'birthDate','')::date, nullif(btrim(v_participant->>'notes'), ''), nullif(btrim(v_participant->>'personDescriptor'), ''), nullif(btrim(v_participant->>'age'), ''), p.is_minor, p.is_senior, p.is_pwd, p.is_active FROM public.persons p WHERE p.id = v_person_id RETURNING id INTO v_new_person_id;
      ELSE
        v_display := nullif(btrim(v_participant->>'fullName'), '');
        IF v_display IS NULL THEN RAISE EXCEPTION 'fullName is required'; END IF;
        INSERT INTO public.persons(first_name,middle_name,last_name,suffix,full_name,gender,birth_date,notes,person_descriptor,age,is_minor,is_senior,is_pwd,is_active)
        SELECT p.first_name, p.middle_name, p.last_name, p.suffix, v_display, nullif(btrim(v_participant->>'gender'), ''), nullif(v_participant->>'birthDate','')::date, nullif(btrim(v_participant->>'notes'), ''), nullif(btrim(v_participant->>'personDescriptor'), ''), nullif(btrim(v_participant->>'age'), ''), p.is_minor, p.is_senior, p.is_pwd, p.is_active FROM public.persons p WHERE p.id = v_person_id RETURNING id INTO v_new_person_id;
      END IF;

      UPDATE public.persons SET is_voided = true, voided_at = now(), voided_by_user_id = v_user_id, void_reason = v_reason, replaced_by_person_id = v_new_person_id, updated_at = now() WHERE id = v_person_id;
      UPDATE public.case_participants SET person_id = v_new_person_id, display_name_snapshot = v_display WHERE id = v_case_participant_id;
      v_person_id := v_new_person_id;
    END IF;

    UPDATE public.case_participants SET display_name_snapshot = v_display WHERE id = v_case_participant_id;
    INSERT INTO public.case_participant_private_details(case_participant_id, case_id, remarks, source, source_detail)
    VALUES (v_case_participant_id, v_case_id, nullif(btrim(v_participant->>'remarks'), ''), 'MANUAL_ENTRY', nullif(btrim(v_participant->>'sourceDetail'), ''))
    ON CONFLICT (case_participant_id) DO UPDATE SET remarks = EXCLUDED.remarks, source_detail = EXCLUDED.source_detail, updated_at = now();
    INSERT INTO public.case_participant_attributes(case_participant_id, age_text, age_years, gender_text, gender_normalized, is_minor_at_case, is_senior_at_case, is_pwd_at_case, notes, updated_by_user_id)
    VALUES (v_case_participant_id, coalesce(nullif(btrim(v_participant->>'ageText'), ''), nullif(btrim(v_participant->>'age'), '')), nullif(v_participant->>'ageYears','')::int, coalesce(nullif(btrim(v_participant->>'genderText'), ''), nullif(btrim(v_participant->>'gender'), '')), nullif(btrim(v_participant->>'genderNormalized'), ''), nullif(v_participant->>'isMinorAtCase','')::boolean, nullif(v_participant->>'isSeniorAtCase','')::boolean, nullif(v_participant->>'isPwdAtCase','')::boolean, nullif(btrim(v_participant->>'attributeNotes'), ''), v_user_id)
    ON CONFLICT (case_participant_id) DO UPDATE SET age_text = EXCLUDED.age_text, age_years = EXCLUDED.age_years, gender_text = EXCLUDED.gender_text, gender_normalized = EXCLUDED.gender_normalized, is_minor_at_case = EXCLUDED.is_minor_at_case, is_senior_at_case = EXCLUDED.is_senior_at_case, is_pwd_at_case = EXCLUDED.is_pwd_at_case, notes = EXCLUDED.notes, updated_by_user_id = EXCLUDED.updated_by_user_id, updated_at = now();

    IF v_kind = 'ORGANIZATION' THEN
      SELECT jsonb_build_object('organization', to_jsonb(o), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_new_snapshot
      FROM public.case_participants cp
      JOIN public.organizations o ON o.id = cp.organization_id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;
      INSERT INTO public.case_participant_corrections(case_id, case_participant_id, old_person_id, new_person_id, old_organization_id, new_organization_id, old_snapshot_json, new_snapshot_json, reason, corrected_by_user_id)
      VALUES (v_case_id, v_case_participant_id, NULL, NULL, (v_old_snapshot#>>'{organization,id}')::bigint, v_new_organization_id, v_old_snapshot, v_new_snapshot, v_reason, v_user_id);
    ELSE
      SELECT jsonb_build_object('person', to_jsonb(p), 'attributes', to_jsonb(cpa), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_new_snapshot
      FROM public.case_participants cp
      JOIN public.persons p ON p.id = cp.person_id
      LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;
      INSERT INTO public.case_participant_corrections(case_id, case_participant_id, old_person_id, new_person_id, old_snapshot_json, new_snapshot_json, reason, corrected_by_user_id)
      VALUES (v_case_id, v_case_participant_id, (v_old_snapshot#>>'{person,id}')::bigint, v_new_person_id, v_old_snapshot, v_new_snapshot, v_reason, v_user_id);
    END IF;
  ELSIF v_action IN ('add_alias','edit_alias','remove_alias') THEN
    IF v_kind = 'ORGANIZATION' THEN
      IF v_action = 'add_alias' THEN INSERT INTO public.organization_aliases(organization_id, alias_name, source) VALUES (v_organization_id, nullif(btrim(v_participant->>'aliasName'), ''), 'MANUAL_ENTRY'); ELSIF v_action = 'edit_alias' THEN UPDATE public.organization_aliases SET alias_name = nullif(btrim(v_participant->>'aliasName'), ''), updated_at = now() WHERE id = v_alias_id AND organization_id = v_organization_id; ELSE UPDATE public.organization_aliases SET is_active = false, updated_at = now() WHERE id = v_alias_id AND organization_id = v_organization_id; END IF;
    ELSE
      IF v_action = 'add_alias' THEN INSERT INTO public.person_aliases(person_id, alias_name, alias_type, source) VALUES (v_person_id, nullif(btrim(v_participant->>'aliasName'), ''), 'AKA', 'MANUAL_ENTRY'); ELSIF v_action = 'edit_alias' THEN UPDATE public.person_aliases SET alias_name = nullif(btrim(v_participant->>'aliasName'), ''), updated_at = now() WHERE id = v_alias_id AND person_id = v_person_id; ELSE UPDATE public.person_aliases SET is_active = false, updated_at = now() WHERE id = v_alias_id AND person_id = v_person_id; END IF;
    END IF;
  ELSIF v_action IN ('add_address','edit_address','remove_address') THEN
    IF v_action = 'remove_address' THEN
      IF v_kind = 'ORGANIZATION' THEN UPDATE public.organization_addresses SET is_active = false, end_date = coalesce(end_date, current_date), deactivated_at = now(), deactivated_by_user_id = v_user_id, deactivation_reason = v_reason WHERE id = v_address_relation_id AND organization_id = v_organization_id; ELSE UPDATE public.person_addresses SET is_active = false, end_date = coalesce(end_date, current_date), deactivated_at = now(), deactivated_by_user_id = v_user_id, deactivation_reason = v_reason WHERE id = v_address_relation_id AND person_id = v_person_id; END IF;
    ELSE
      IF v_address_type_id IS NULL THEN RAISE EXCEPTION 'addressTypeId is required'; END IF;
      IF v_action = 'add_address' THEN
        INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country) VALUES (nullif(btrim(v_participant->>'line1'),''), nullif(btrim(v_participant->>'line2'),''), nullif(btrim(v_participant->>'barangay'),''), nullif(btrim(v_participant->>'city'),''), nullif(btrim(v_participant->>'province'),''), nullif(btrim(v_participant->>'region'),''), nullif(btrim(v_participant->>'zipCode'),''), coalesce(nullif(btrim(v_participant->>'country'),''), 'Philippines')) RETURNING id INTO v_address_id;
        IF v_kind = 'ORGANIZATION' THEN INSERT INTO public.organization_addresses(organization_id,address_id,address_type_id,is_primary,remarks) VALUES (v_organization_id,v_address_id,v_address_type_id,coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),nullif(btrim(v_participant->>'remarks'),'')); ELSE INSERT INTO public.person_addresses(person_id,address_id,address_type_id,is_primary,remarks) VALUES (v_person_id,v_address_id,v_address_type_id,coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),nullif(btrim(v_participant->>'remarks'),'')); END IF;
      ELSE
        IF v_kind = 'ORGANIZATION' THEN SELECT address_id INTO v_address_id FROM public.organization_addresses WHERE id = v_address_relation_id AND organization_id = v_organization_id; ELSE SELECT address_id INTO v_address_id FROM public.person_addresses WHERE id = v_address_relation_id AND person_id = v_person_id; END IF;
        UPDATE public.addresses SET line1=nullif(btrim(v_participant->>'line1'),''), line2=nullif(btrim(v_participant->>'line2'),''), barangay=nullif(btrim(v_participant->>'barangay'),''), city=nullif(btrim(v_participant->>'city'),''), province=nullif(btrim(v_participant->>'province'),''), region=nullif(btrim(v_participant->>'region'),''), zip_code=nullif(btrim(v_participant->>'zipCode'),''), country=coalesce(nullif(btrim(v_participant->>'country'),''),'Philippines') WHERE id = v_address_id;
        IF v_kind = 'ORGANIZATION' THEN UPDATE public.organization_addresses SET address_type_id=v_address_type_id,is_primary=coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),remarks=nullif(btrim(v_participant->>'remarks'),'') WHERE id=v_address_relation_id AND organization_id=v_organization_id; ELSE UPDATE public.person_addresses SET address_type_id=v_address_type_id,is_primary=coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),remarks=nullif(btrim(v_participant->>'remarks'),'') WHERE id=v_address_relation_id AND person_id=v_person_id; END IF;
      END IF;
    END IF;
  ELSIF v_action IN ('add_contact','edit_contact','remove_contact') THEN
    IF v_action = 'remove_contact' THEN UPDATE public.participant_contact_informations SET is_active = false, deactivated_at = now(), deactivated_by_user_id = v_user_id, deactivation_reason = v_reason WHERE id = v_contact_relation_id AND case_participant_id = v_case_participant_id;
    ELSIF v_action = 'add_contact' THEN INSERT INTO public.contact_informations(contact_type,contact_value,label,is_primary,remarks) VALUES (coalesce(nullif(btrim(v_participant->>'contactType'),''),'OTHER'), nullif(btrim(v_participant->>'contactValue'),''), nullif(btrim(v_participant->>'label'),''), coalesce(nullif(v_participant->>'isPrimary','')::boolean,false), nullif(btrim(v_participant->>'remarks'),'')) RETURNING id INTO v_contact_id; INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_case_participant_id, v_contact_id);
    ELSE SELECT contact_information_id INTO v_contact_id FROM public.participant_contact_informations WHERE id = v_contact_relation_id AND case_participant_id = v_case_participant_id; UPDATE public.contact_informations SET contact_type=coalesce(nullif(btrim(v_participant->>'contactType'),''),'OTHER'), contact_value=nullif(btrim(v_participant->>'contactValue'),''), label=nullif(btrim(v_participant->>'label'),''), is_primary=coalesce(nullif(v_participant->>'isPrimary','')::boolean,false), remarks=nullif(btrim(v_participant->>'remarks'),''), updated_at=now() WHERE id = v_contact_id; END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported participants action %', v_action;
  END IF;

  IF v_action = 'edit_main_details' THEN
    IF v_kind = 'ORGANIZATION' THEN
      PERFORM public.upsert_clearance_possible_tokens_for_organization((v_old_snapshot#>>'{organization,id}')::bigint);
      PERFORM public.upsert_clearance_phonetic_tokens_for_organization((v_old_snapshot#>>'{organization,id}')::bigint);
      PERFORM public.upsert_clearance_possible_tokens_for_organization(v_organization_id);
      PERFORM public.upsert_clearance_phonetic_tokens_for_organization(v_organization_id);
    ELSE
      PERFORM public.upsert_clearance_possible_tokens_for_person((v_old_snapshot#>>'{person,id}')::bigint);
      PERFORM public.upsert_clearance_phonetic_tokens_for_person((v_old_snapshot#>>'{person,id}')::bigint);
      PERFORM public.upsert_clearance_possible_tokens_for_person(v_person_id);
      PERFORM public.upsert_clearance_phonetic_tokens_for_person(v_person_id);
    END IF;
  END IF;

  SELECT to_jsonb(vcp) INTO v_new FROM public.v_case_participants_detail vcp WHERE vcp.id = v_case_participant_id;
  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_PARTICIPANTS_' || upper(v_action), 'case_participants', v_case_participant_id, v_case_id, CASE WHEN v_action = 'edit_main_details' AND v_kind <> 'ORGANIZATION' THEN 'Corrected case participant identity' ELSE 'Managed case participant' END, jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;


--
-- Name: manage_case_places(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_case_places(p_payload jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_action text := lower(btrim(p_payload->>'action'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_place jsonb := coalesce(p_payload->'place', '{}'::jsonb);
  v_case_address_id bigint := nullif(v_place->>'id','')::bigint;
  v_address_id bigint := nullif(v_place->>'addressId','')::bigint;
  v_address_type_id bigint;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(ca) || jsonb_build_object('address', to_jsonb(a), 'address_type', to_jsonb(at)) ORDER BY ca.id), '[]'::jsonb)
  INTO v_old
  FROM public.case_addresses ca
  JOIN public.addresses a ON a.id = ca.address_id
  LEFT JOIN public.address_types at ON at.id = ca.address_type_id
  WHERE ca.case_id = v_case_id;

  IF v_action IN ('add', 'edit') THEN
    v_address_type_id := nullif(v_place->>'addressTypeId','')::bigint;
    IF v_address_type_id IS NULL THEN
      SELECT id INTO v_address_type_id
      FROM public.address_types
      WHERE is_active IS TRUE
        AND (
          upper(code) IN ('PLACE_OF_COMMISSION', 'COMMISSION_PLACE', 'POC')
          OR display_label ILIKE '%commission%'
        )
      ORDER BY CASE WHEN upper(code) = 'PLACE_OF_COMMISSION' THEN 0 ELSE 1 END, id
      LIMIT 1;
    END IF;
    IF v_address_type_id IS NULL THEN RAISE EXCEPTION 'Missing address type for Place of Commission'; END IF;
    IF v_action = 'add' THEN
      INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country,latitude,longitude)
      VALUES (nullif(btrim(v_place->>'line1'),''), nullif(btrim(v_place->>'line2'),''), nullif(btrim(v_place->>'barangay'),''), nullif(btrim(v_place->>'city'),''), nullif(btrim(v_place->>'province'),''), nullif(btrim(v_place->>'region'),''), nullif(btrim(v_place->>'zipCode'),''), coalesce(nullif(btrim(v_place->>'country'),''), 'Philippines'), nullif(v_place->>'latitude','')::numeric, nullif(v_place->>'longitude','')::numeric)
      RETURNING id INTO v_address_id;
      INSERT INTO public.case_addresses(case_id,address_id,address_type_id,is_primary,remarks)
      VALUES (v_case_id, v_address_id, v_address_type_id, coalesce(nullif(v_place->>'isPrimary','')::boolean,false), nullif(btrim(v_place->>'remarks'),''))
      RETURNING id INTO v_case_address_id;
    ELSE
      IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
      SELECT address_id INTO v_address_id FROM public.case_addresses WHERE id = v_case_address_id AND case_id = v_case_id;
      IF v_address_id IS NULL THEN RAISE EXCEPTION 'Place % not found', v_case_address_id; END IF;
      IF EXISTS (SELECT 1 FROM public.case_addresses WHERE id = v_case_address_id AND case_id = v_case_id AND is_deleted IS TRUE) THEN RAISE EXCEPTION 'Restore place before editing'; END IF;
      UPDATE public.addresses SET line1=nullif(btrim(v_place->>'line1'),''), line2=nullif(btrim(v_place->>'line2'),''), barangay=nullif(btrim(v_place->>'barangay'),''), city=nullif(btrim(v_place->>'city'),''), province=nullif(btrim(v_place->>'province'),''), region=nullif(btrim(v_place->>'region'),''), zip_code=nullif(btrim(v_place->>'zipCode'),''), country=coalesce(nullif(btrim(v_place->>'country'),''), 'Philippines'), latitude=nullif(v_place->>'latitude','')::numeric, longitude=nullif(v_place->>'longitude','')::numeric WHERE id = v_address_id;
      UPDATE public.case_addresses SET address_type_id=v_address_type_id, is_primary=coalesce(nullif(v_place->>'isPrimary','')::boolean,false), remarks=nullif(btrim(v_place->>'remarks'),'') WHERE id = v_case_address_id AND case_id = v_case_id;
    END IF;
    IF coalesce(nullif(v_place->>'isPrimary','')::boolean,false) IS TRUE THEN
      UPDATE public.case_addresses
      SET is_primary = false
      WHERE case_id = v_case_id
        AND id <> v_case_address_id
        AND coalesce(is_deleted, false) IS FALSE;
    END IF;
  ELSIF v_action = 'remove' THEN
    IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_addresses SET is_deleted = true, deleted_at = now(), deleted_by_user_id = v_user_id, delete_reason = v_reason WHERE id = v_case_address_id AND case_id = v_case_id;
  ELSIF v_action = 'restore' THEN
    IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_addresses SET is_deleted = false, deleted_at = NULL, deleted_by_user_id = NULL, delete_reason = NULL WHERE id = v_case_address_id AND case_id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Unsupported places action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(ca) || jsonb_build_object('address', to_jsonb(a), 'address_type', to_jsonb(at)) ORDER BY ca.id), '[]'::jsonb)
  INTO v_new
  FROM public.case_addresses ca
  JOIN public.addresses a ON a.id = ca.address_id
  LEFT JOIN public.address_types at ON at.id = ca.address_type_id
  WHERE ca.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_PLACES_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed places of commission', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;


--
-- Name: manage_case_violations(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_case_violations(p_payload jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_action text := lower(btrim(p_payload->>'action'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_violation jsonb := coalesce(p_payload->'violation', '{}'::jsonb);
  v_case_violation_id bigint := nullif(v_violation->>'id','')::bigint;
  v_violation_id bigint := nullif(v_violation->>'violationId','')::bigint;
  v_violation_order integer := nullif(v_violation->>'violationOrder','')::integer;
  v_raw_violation_text text := nullif(btrim(v_violation->>'rawViolationText'), '');
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(cv) || jsonb_build_object('violation', to_jsonb(v)) ORDER BY cv.violation_order NULLS LAST, cv.id), '[]'::jsonb)
  INTO v_old
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  WHERE cv.case_id = v_case_id;

  IF v_action IN ('add', 'edit') THEN
    IF v_violation_id IS NULL THEN RAISE EXCEPTION 'violationId is required'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.violations WHERE id = v_violation_id) THEN RAISE EXCEPTION 'Violation % not found', v_violation_id; END IF;
    IF v_action = 'add' THEN
      INSERT INTO public.case_violations(case_id,violation_id,violation_order,raw_violation_text)
      VALUES (v_case_id, v_violation_id, COALESCE(v_violation_order, (SELECT COALESCE(max(cv.violation_order), 0) + 1 FROM public.case_violations cv WHERE cv.case_id = v_case_id)), v_raw_violation_text);
    ELSE
      IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
      IF EXISTS (SELECT 1 FROM public.case_violations WHERE id = v_case_violation_id AND case_id = v_case_id AND is_deleted IS TRUE) THEN RAISE EXCEPTION 'Restore violation before editing'; END IF;
      UPDATE public.case_violations
      SET violation_id = v_violation_id,
          violation_order = v_violation_order,
          raw_violation_text = v_raw_violation_text
      WHERE id = v_case_violation_id AND case_id = v_case_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
    END IF;
  ELSIF v_action = 'remove' THEN
    IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_violations
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by_user_id = v_user_id,
        delete_reason = v_reason
    WHERE id = v_case_violation_id AND case_id = v_case_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
  ELSIF v_action = 'restore' THEN
    IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_violations
    SET is_deleted = false,
        deleted_at = NULL,
        deleted_by_user_id = NULL,
        delete_reason = NULL
    WHERE id = v_case_violation_id AND case_id = v_case_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported violations action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(cv) || jsonb_build_object('violation', to_jsonb(v)) ORDER BY cv.violation_order NULLS LAST, cv.id), '[]'::jsonb)
  INTO v_new
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  WHERE cv.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_VIOLATIONS_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed case violations', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
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
-- Name: recompute_case_status_after_court_filing(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recompute_case_status_after_court_filing(p_case_id bigint) RETURNS TABLE(status_code text, status_label text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_unapproved integer;
  v_unfiled_for_filing integer;
  v_for_filing integer;
  v_dismissal integer;
  v_active_filing integer;
  v_active_assignment integer;
BEGIN
  SELECT count(*) INTO v_unapproved
  FROM public.case_resolutions cr
  WHERE cr.case_id = p_case_id AND cr.is_voided = false
    AND NOT EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id = cr.id AND a.is_voided = false);

  SELECT
    count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING'),
    count(*) FILTER (WHERE aa.decision_code = 'DISMISSAL'),
    count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING' AND NOT EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id = aa.id AND cf.is_voided = false))
  INTO v_for_filing, v_dismissal, v_unfiled_for_filing
  FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a ON a.id = aa.approval_id AND a.is_voided = false
  JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id AND cr.is_voided = false
  WHERE aa.case_id = p_case_id;

  SELECT count(*) INTO v_active_filing
  FROM public.case_court_filings cf
  WHERE cf.case_id = p_case_id
    AND cf.is_voided = false;

  IF COALESCE(v_unapproved, 0) > 0 THEN
    IF COALESCE(v_active_filing, 0) > 0 THEN
      RETURN QUERY SELECT 'FILED_OTHER_RESO_FOR_APPROVAL'::text, 'Filed; other resolution for approval'::text;
    ELSE
      RETURN QUERY SELECT 'RESO_FOR_APPROVAL'::text, 'Reso for Approval'::text;
    END IF;
  ELSIF COALESCE(v_unfiled_for_filing, 0) > 0 THEN
    IF COALESCE(v_active_filing, 0) > 0 THEN
      RETURN QUERY SELECT 'FILED_OTHER_INFO_FOR_FILING'::text, 'Filed; other info for filing'::text;
    ELSE
      RETURN QUERY SELECT 'FOR_FILING'::text, 'For Filing'::text;
    END IF;
  ELSIF COALESCE(v_for_filing, 0) > 0 AND COALESCE(v_dismissal, 0) > 0 THEN
    RETURN QUERY SELECT 'MIXED_RESULT'::text, 'Mixed Result'::text;
  ELSIF COALESCE(v_for_filing, 0) > 0 AND COALESCE(v_dismissal, 0) = 0 THEN
    RETURN QUERY SELECT 'FILED'::text, 'Filed'::text;
  ELSIF COALESCE(v_dismissal, 0) > 0 AND COALESCE(v_for_filing, 0) = 0 THEN
    RETURN QUERY SELECT 'DISMISSED'::text, 'Dismissed'::text;
  ELSE
    SELECT count(*) INTO v_active_assignment FROM public.case_assignments ca WHERE ca.case_id = p_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE;
    IF COALESCE(v_active_assignment, 0) > 0 THEN RETURN QUERY SELECT 'PENDING'::text, 'Pending'::text; END IF;
  END IF;
END;
$$;


--
-- Name: record_case_assignment_event(bigint, bigint, date, time without time zone, bigint, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_case_assignment_event(p_case_id bigint, p_prosecutor_id bigint, p_assignment_date date, p_assignment_time time without time zone DEFAULT NULL::time without time zone, p_staff_id bigint DEFAULT NULL::bigint, p_remarks text DEFAULT NULL::text, p_user_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_event_type_id bigint;
  v_pending_status_id bigint;
  v_case_raffled_stage_id bigint;
  v_event_id bigint;
  v_assignment_id bigint;
  v_status_history_id bigint;
  v_stage_history_id bigint;
  v_previous_status_id bigint;
  v_previous_case_status_id bigint;
  v_previous_stage_id bigint;
  v_assigned_at timestamptz;
  v_prosecutor_name text;
  v_staff_name text;
  v_old_details jsonb;
  v_new_details jsonb;
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Assigned prosecutor is required'; END IF;
  IF p_assignment_date IS NULL THEN RAISE EXCEPTION 'Assignment date is required'; END IF;

  SELECT id INTO v_event_type_id
  FROM public.case_event_types
  WHERE code = 'CASE_ASSIGNMENT' AND is_active IS TRUE
  LIMIT 1;

  IF v_event_type_id IS NULL THEN
    RAISE EXCEPTION 'Missing active case event type CASE_ASSIGNMENT';
  END IF;

  SELECT id INTO v_pending_status_id
  FROM public.case_statuses
  WHERE code = 'PENDING' AND is_active IS TRUE
  LIMIT 1;

  IF v_pending_status_id IS NULL THEN
    INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active)
    VALUES ('PENDING', 'Pending', 20, false, false, true)
    ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, sort_order = EXCLUDED.sort_order, is_final = false, is_milestone = false, is_active = true
    RETURNING id INTO v_pending_status_id;
  END IF;

  SELECT id INTO v_case_raffled_stage_id
  FROM public.case_stages
  WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE
  LIMIT 1;

  IF v_case_raffled_stage_id IS NULL THEN
    RAISE EXCEPTION 'Missing active case stage CASE_RAFFLED';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = p_prosecutor_id) THEN
    RAISE EXCEPTION 'Unknown prosecutor id %', p_prosecutor_id;
  END IF;

  IF p_staff_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.staff WHERE id = p_staff_id) THEN
    RAISE EXCEPTION 'Unknown staff id %', p_staff_id;
  END IF;

  SELECT cpd.current_status_id, cpd.current_case_status_id, cpd.current_case_stage_id, to_jsonb(cpd)
  INTO v_previous_status_id, v_previous_case_status_id, v_previous_stage_id, v_old_details
  FROM public.case_private_details cpd
  WHERE cpd.case_id = p_case_id;

  v_assigned_at := (p_assignment_date::timestamp + COALESCE(p_assignment_time, '00:00'::time))::timestamptz;

  SELECT COALESCE(short_name, full_name) INTO v_prosecutor_name
  FROM public.prosecutors
  WHERE id = p_prosecutor_id;

  SELECT COALESCE(short_name, full_name) INTO v_staff_name
  FROM public.staff
  WHERE id = p_staff_id;

  IF EXISTS (
    SELECT 1
    FROM public.case_assignments ca
    WHERE ca.case_id = p_case_id
      AND ca.unassigned_at IS NULL
      AND ca.is_voided IS FALSE
  ) THEN
    RAISE EXCEPTION 'This case already has an active assignment. Void or reassign the current assignment first.';
  END IF;

  INSERT INTO public.case_events (
    case_id, event_type_id, event_date, event_time, title, description,
    status_id, case_status_id, case_stage_id,
    prosecutor_id, staff_id, details_jsonb, source, created_by_user_id, updated_by_user_id
  ) VALUES (
    p_case_id,
    v_event_type_id,
    p_assignment_date,
    p_assignment_time,
    'Case Assignment',
    'Assigned to Prosec ' || COALESCE(v_prosecutor_name, p_prosecutor_id::text) || ' on ' || to_char(p_assignment_date, 'Mon DD, YYYY'),
    v_pending_status_id,
    v_pending_status_id,
    v_case_raffled_stage_id,
    p_prosecutor_id,
    p_staff_id,
    jsonb_build_object(
      'action', 'case_assignment',
      'new_prosecutor_id', p_prosecutor_id,
      'new_prosecutor_name', v_prosecutor_name,
      'staff_id', p_staff_id,
      'staff_name', v_staff_name,
      'remarks', NULLIF(btrim(COALESCE(p_remarks, '')), ''),
      'automatic_status', 'Pending',
      'automatic_case_status', 'Pending',
      'automatic_case_stage', 'Case Raffled'
    ),
    'MANUAL_ENTRY', p_user_id, p_user_id
  ) RETURNING id INTO v_event_id;

  INSERT INTO public.case_assignments (case_id, prosecutor_id, staff_id, assigned_by_user_id, assigned_at, remarks, case_event_id)
  VALUES (p_case_id, p_prosecutor_id, p_staff_id, p_user_id, v_assigned_at, NULLIF(btrim(COALESCE(p_remarks, '')), ''), v_event_id)
  RETURNING id INTO v_assignment_id;

  UPDATE public.case_events
  SET source_table = 'case_assignments', source_id = v_assignment_id, updated_by_user_id = p_user_id
  WHERE id = v_event_id;

  INSERT INTO public.case_status_history (
    case_id, from_status_id, to_status_id, changed_by_user_id, changed_at, status_date, remarks, case_event_id
  ) VALUES (
    p_case_id,
    COALESCE(v_previous_case_status_id, v_previous_status_id),
    v_pending_status_id,
    p_user_id,
    now(),
    p_assignment_date,
    'Case Assignment recorded. Broad case status set to Pending.',
    v_event_id
  ) RETURNING id INTO v_status_history_id;

  INSERT INTO public.case_stage_history (
    case_id, from_stage_id, to_stage_id, changed_by_user_id, changed_at, stage_date, remarks, case_event_id
  ) VALUES (
    p_case_id,
    v_previous_stage_id,
    v_case_raffled_stage_id,
    p_user_id,
    now(),
    p_assignment_date,
    'Case Assignment recorded. Workflow stage set to Case Raffled.',
    v_event_id
  ) RETURNING id INTO v_stage_history_id;

  INSERT INTO public.case_private_details (
    case_id,
    current_status_id,
    current_status_date,
    current_case_status_id,
    current_case_status_date,
    current_case_stage_id,
    current_case_stage_date,
    updated_at
  )
  VALUES (
    p_case_id,
    v_pending_status_id,
    p_assignment_date,
    v_pending_status_id,
    p_assignment_date,
    v_case_raffled_stage_id,
    p_assignment_date,
    now()
  )
  ON CONFLICT (case_id) DO UPDATE SET
    current_status_id = EXCLUDED.current_status_id,
    current_status_date = EXCLUDED.current_status_date,
    current_case_status_id = EXCLUDED.current_case_status_id,
    current_case_status_date = EXCLUDED.current_case_status_date,
    current_case_stage_id = EXCLUDED.current_case_stage_id,
    current_case_stage_date = EXCLUDED.current_case_stage_date,
    updated_at = now();

  SELECT to_jsonb(cpd) INTO v_new_details
  FROM public.case_private_details cpd
  WHERE cpd.case_id = p_case_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (
    p_user_id,
    'case_assignments',
    v_assignment_id,
    'CASE_ASSIGNED_CASE_RAFFLED_STAGE',
    v_old_details,
    v_new_details,
    p_case_id,
    'Case assigned to ' || COALESCE(v_prosecutor_name, 'selected prosecutor') || '; case status set to Pending and case stage set to Case Raffled.',
    jsonb_build_object(
      'case_event_id', v_event_id,
      'assignment_id', v_assignment_id,
      'status_id', v_pending_status_id,
      'case_status_id', v_pending_status_id,
      'case_stage_id', v_case_raffled_stage_id,
      'status_history_id', v_status_history_id,
      'case_stage_history_id', v_stage_history_id
    )
  );

  RETURN v_event_id;
END;
$$;


--
-- Name: record_case_decision_approved_event(bigint, bigint, bigint, date, time without time zone, jsonb, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_case_decision_approved_event(p_case_id bigint, p_case_resolution_id bigint DEFAULT NULL::bigint, p_approved_by_prosecutor_id bigint DEFAULT NULL::bigint, p_date_approved date DEFAULT NULL::date, p_time_approved time without time zone DEFAULT NULL::time without time zone, p_approval_actions jsonb DEFAULT '[]'::jsonb, p_remarks text DEFAULT NULL::text, p_user_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_event_type_id bigint;
  v_status_id bigint;
  v_previous_status_id bigint;
  v_event_id bigint;
  v_approval_id bigint;
  v_status_history_id bigint;
  v_approver_name text;
  v_approver_position_code text;
  v_approver_position_group_type text;
  v_event_final_status_code text;
  v_event_final_status_label text;
  v_case_final_status_code text;
  v_case_final_status_label text;
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
  v_old_details jsonb;
  v_new_details jsonb;
  v_action jsonb;
  v_action_count integer;
  v_for_filing_count integer;
  v_dismissal_count integer;
  v_existing_for_filing_count integer;
  v_existing_dismissal_count integer;
  v_total_for_filing_count integer;
  v_total_dismissal_count integer;
  v_total_action_count integer;
  v_pending_unapproved_resolution_count integer;
  v_active_assignment_count integer;
  v_display_order integer := 0;
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_approved_by_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Approved by prosecutor is required'; END IF;
  IF p_date_approved IS NULL THEN RAISE EXCEPTION 'Date approved is required'; END IF;
  IF jsonb_typeof(COALESCE(p_approval_actions, '[]'::jsonb)) <> 'array' THEN RAISE EXCEPTION 'Approval actions must be an array'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  SELECT pr.full_name, p.code, p.group_type INTO v_approver_name, v_approver_position_code, v_approver_position_group_type
  FROM public.prosecutors pr
  JOIN public.positions p ON p.id = pr.position_id
  WHERE pr.id = p_approved_by_prosecutor_id
    AND pr.is_active = true
    AND p.is_active = true;

  IF v_approver_name IS NULL THEN RAISE EXCEPTION 'Unknown prosecutor id %', p_approved_by_prosecutor_id; END IF;
  IF COALESCE(v_approver_position_group_type, '') <> 'PROSECUTOR' OR COALESCE(v_approver_position_code, '') NOT IN ('CHIEF_PROSECUTOR', 'DEPUTY_PROSECUTOR') THEN
    RAISE EXCEPTION 'Approver must be a Chief Prosecutor or Deputy Prosecutor';
  END IF;

  IF p_case_resolution_id IS NULL THEN
    RAISE EXCEPTION 'Case resolution id is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.case_resolutions WHERE id = p_case_resolution_id AND case_id = p_case_id) THEN
    RAISE EXCEPTION 'Resolution % does not belong to case %', p_case_resolution_id, p_case_id;
  END IF;

  IF EXISTS (SELECT 1 FROM public.case_resolutions WHERE id = p_case_resolution_id AND case_id = p_case_id AND is_voided = true) THEN
    RAISE EXCEPTION 'Voided resolution cannot be approved.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.case_resolution_approvals WHERE case_resolution_id = p_case_resolution_id AND is_voided = false) THEN
    RAISE EXCEPTION 'This resolution already has an active approved decision.';
  END IF;

  SELECT count(*), count(*) FILTER (WHERE action.value->>'decision_code' = 'FOR_FILING'), count(*) FILTER (WHERE action.value->>'decision_code' = 'DISMISSAL')
  INTO v_action_count, v_for_filing_count, v_dismissal_count
  FROM jsonb_array_elements(COALESCE(p_approval_actions, '[]'::jsonb)) AS action(value)
  WHERE NULLIF(btrim(COALESCE(action.value->>'charge_text', '')), '') IS NOT NULL
    AND action.value->>'decision_code' IN ('FOR_FILING', 'DISMISSAL');

  IF v_action_count < 1 THEN RAISE EXCEPTION 'At least one approval action is required'; END IF;

  v_event_final_status_code := CASE
    WHEN v_for_filing_count = v_action_count THEN 'FOR_FILING'
    WHEN v_dismissal_count = v_action_count THEN 'DISMISSED'
    ELSE 'MIXED_RESULT'
  END;
  v_event_final_status_label := CASE v_event_final_status_code WHEN 'FOR_FILING' THEN 'For Filing' WHEN 'DISMISSED' THEN 'Dismissed' ELSE 'Mixed Result' END;

  SELECT
    count(*) FILTER (WHERE decision_code = 'FOR_FILING'),
    count(*) FILTER (WHERE decision_code = 'DISMISSAL')
  INTO v_existing_for_filing_count, v_existing_dismissal_count
  FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a ON a.id = aa.approval_id
  WHERE aa.case_id = p_case_id
    AND a.is_voided = false;

  v_total_for_filing_count := COALESCE(v_existing_for_filing_count, 0) + COALESCE(v_for_filing_count, 0);
  v_total_dismissal_count := COALESCE(v_existing_dismissal_count, 0) + COALESCE(v_dismissal_count, 0);
  v_total_action_count := v_total_for_filing_count + v_total_dismissal_count;

  SELECT count(*)
  INTO v_pending_unapproved_resolution_count
  FROM public.case_resolutions cr
  WHERE cr.case_id = p_case_id
    AND cr.id <> p_case_resolution_id
    AND cr.is_voided = false
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_resolution_approvals a
      WHERE a.case_resolution_id = cr.id
        AND a.is_voided = false
    );

  IF COALESCE(v_pending_unapproved_resolution_count, 0) > 0 THEN
    v_case_final_status_code := 'RESO_FOR_APPROVAL';
  ELSIF v_total_action_count < 1 THEN
    SELECT count(*)
    INTO v_active_assignment_count
    FROM public.case_assignments ca
    WHERE ca.case_id = p_case_id
      AND ca.unassigned_at IS NULL
      AND ca.is_voided IS FALSE;

    IF COALESCE(v_active_assignment_count, 0) > 0 THEN
      v_case_final_status_code := 'PENDING';
    ELSE
      RAISE EXCEPTION 'At least one approval action is required';
    END IF;
  ELSIF v_total_for_filing_count > 0 AND v_total_dismissal_count > 0 THEN
    v_case_final_status_code := 'MIXED_RESULT';
  ELSIF v_total_for_filing_count > 0 THEN
    v_case_final_status_code := 'FOR_FILING';
  ELSIF v_total_dismissal_count > 0 THEN
    v_case_final_status_code := 'DISMISSED';
  END IF;

  v_case_final_status_label := CASE v_case_final_status_code WHEN 'PENDING' THEN 'Pending' WHEN 'RESO_FOR_APPROVAL' THEN 'Reso for Approval' WHEN 'FOR_FILING' THEN 'For Filing' WHEN 'DISMISSED' THEN 'Dismissed' ELSE 'Mixed Result' END;

  INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
  VALUES ('CASE_DECISION_APPROVED', 'Case Decision Approved', 'CASE', 'Manual timeline event for approving a prosecutor recommendation or final case decision.', 130, true, true)
  ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, category = EXCLUDED.category, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, is_active = true, updated_at = now()
  RETURNING id INTO v_event_type_id;

  INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active)
  VALUES (v_case_final_status_code, v_case_final_status_label, CASE v_case_final_status_code WHEN 'PENDING' THEN 20 WHEN 'RESO_FOR_APPROVAL' THEN 80 WHEN 'FOR_FILING' THEN 90 WHEN 'DISMISSED' THEN 100 ELSE 110 END, v_case_final_status_code NOT IN ('PENDING', 'RESO_FOR_APPROVAL'), v_case_final_status_code <> 'PENDING', true)
  ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, sort_order = EXCLUDED.sort_order, is_final = EXCLUDED.is_final, is_milestone = EXCLUDED.is_milestone, is_active = true
  RETURNING id INTO v_status_id;

  SELECT cpd.current_status_id, to_jsonb(cpd) INTO v_previous_status_id, v_old_details
  FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  INSERT INTO public.case_events (case_id, event_type_id, event_date, event_time, title, description, status_id, details_jsonb, source, created_by_user_id, updated_by_user_id)
  VALUES (p_case_id, v_event_type_id, p_date_approved, p_time_approved, 'Case Decision Approved', 'Decision approved by Prosec ' || v_approver_name || ' on ' || to_char(p_date_approved, 'Mon FMDD, YYYY'), v_status_id,
    jsonb_build_object('approved_by_prosecutor_id', p_approved_by_prosecutor_id, 'approved_by_name', v_approver_name, 'date_approved', p_date_approved, 'time_approved', p_time_approved, 'final_status_code', v_case_final_status_code, 'final_status_label', v_case_final_status_label, 'event_final_status_code', v_event_final_status_code, 'event_final_status_label', v_event_final_status_label, 'case_final_status_code', v_case_final_status_code, 'case_final_status_label', v_case_final_status_label, 'remarks', v_remarks),
    'MANUAL_ENTRY', p_user_id, p_user_id)
  RETURNING id INTO v_event_id;

  INSERT INTO public.case_resolution_approvals (case_id, case_event_id, case_resolution_id, approved_by_prosecutor_id, date_approved, time_approved, final_status_code, remarks, created_by_user_id, updated_by_user_id)
  VALUES (p_case_id, v_event_id, p_case_resolution_id, p_approved_by_prosecutor_id, p_date_approved, p_time_approved, v_event_final_status_code, v_remarks, p_user_id, p_user_id)
  RETURNING id INTO v_approval_id;

  FOR v_action IN SELECT * FROM jsonb_array_elements(COALESCE(p_approval_actions, '[]'::jsonb)) LOOP
    IF NULLIF(btrim(COALESCE(v_action->>'charge_text', '')), '') IS NOT NULL AND v_action->>'decision_code' IN ('FOR_FILING', 'DISMISSAL') THEN
      IF NULLIF(v_action->>'source_resolution_charge_action_id', '') IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.case_resolution_charge_actions src
        WHERE src.id = NULLIF(v_action->>'source_resolution_charge_action_id', '')::bigint
          AND src.case_id = p_case_id
          AND src.case_resolution_id = p_case_resolution_id
      ) THEN
        RAISE EXCEPTION 'Selected recommendation action does not belong to this case resolution.';
      END IF;

      v_display_order := v_display_order + 1;
      INSERT INTO public.case_resolution_approval_actions (approval_id, case_id, source_resolution_charge_action_id, case_violation_id, violation_id, charge_text, decision_code, display_order, remarks)
      VALUES (v_approval_id, p_case_id, NULLIF(v_action->>'source_resolution_charge_action_id', '')::bigint, NULLIF(v_action->>'case_violation_id', '')::bigint, NULLIF(v_action->>'violation_id', '')::bigint, NULLIF(btrim(v_action->>'charge_text'), ''), v_action->>'decision_code', v_display_order, NULLIF(btrim(COALESCE(v_action->>'remarks', '')), ''));
    END IF;
  END LOOP;

  UPDATE public.case_events
  SET source_table = 'case_resolution_approvals', source_id = v_approval_id,
      details_jsonb = details_jsonb || jsonb_build_object('approval_actions', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', aa.id, 'source_resolution_charge_action_id', aa.source_resolution_charge_action_id, 'case_violation_id', aa.case_violation_id, 'violation_id', aa.violation_id, 'charge_text', aa.charge_text, 'decision_code', aa.decision_code, 'display_order', aa.display_order, 'remarks', aa.remarks) ORDER BY aa.display_order, aa.id) FROM public.case_resolution_approval_actions aa WHERE aa.approval_id = v_approval_id), '[]'::jsonb)),
      updated_by_user_id = p_user_id, updated_at = now()
  WHERE id = v_event_id;

  INSERT INTO public.case_private_details (case_id, current_status_id, current_status_date, current_status_remarks, updated_at)
  VALUES (p_case_id, v_status_id, p_date_approved, v_remarks, now())
  ON CONFLICT (case_id) DO UPDATE SET current_status_id = EXCLUDED.current_status_id, current_status_date = EXCLUDED.current_status_date, current_status_remarks = EXCLUDED.current_status_remarks, updated_at = now();

  INSERT INTO public.case_status_history (case_id, from_status_id, to_status_id, changed_by_user_id, changed_at, status_date, remarks, case_event_id)
  VALUES (p_case_id, v_previous_status_id, v_status_id, p_user_id, now(), p_date_approved, v_remarks, v_event_id)
  RETURNING id INTO v_status_history_id;

  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (p_user_id, 'case_resolution_approvals', v_approval_id, 'CASE_DECISION_APPROVED', v_old_details, v_new_details, p_case_id, 'Case decision approved as ' || v_case_final_status_label || '.', jsonb_build_object('case_event_id', v_event_id, 'status_history_id', v_status_history_id, 'event_final_status_code', v_event_final_status_code, 'case_final_status_code', v_case_final_status_code));

  RETURN v_event_id;
END;
$$;


--
-- Name: record_case_reassignment_event(bigint, bigint, date, time without time zone, bigint, text, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_case_reassignment_event(p_case_id bigint, p_new_prosecutor_id bigint, p_reassignment_date date, p_reassignment_time time without time zone DEFAULT NULL::time without time zone, p_new_staff_id bigint DEFAULT NULL::bigint, p_reason text DEFAULT NULL::text, p_remarks text DEFAULT NULL::text, p_user_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_event_type_id bigint;
  v_pending_status_id bigint;
  v_case_reassigned_stage_id bigint;
  v_event_id bigint;
  v_previous_assignment_id bigint;
  v_previous_prosecutor_id bigint;
  v_previous_staff_id bigint;
  v_previous_assignment_old jsonb;
  v_previous_assignment_new jsonb;
  v_new_assignment_id bigint;
  v_new_assignment_new jsonb;
  v_status_history_id bigint;
  v_stage_history_id bigint;
  v_previous_status_id bigint;
  v_previous_case_status_id bigint;
  v_previous_stage_id bigint;
  v_old_details jsonb;
  v_new_details jsonb;
  v_reassigned_at timestamptz;
  v_previous_prosecutor_name text;
  v_new_prosecutor_name text;
  v_staff_name text;
  v_reason text := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_new_prosecutor_id IS NULL THEN RAISE EXCEPTION 'New prosecutor is required'; END IF;
  IF p_reassignment_date IS NULL THEN RAISE EXCEPTION 'Reassignment date is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'Reason is required'; END IF;

  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'CASE_REASSIGNMENT' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing active case event type CASE_REASSIGNMENT'; END IF;

  SELECT id INTO v_pending_status_id FROM public.case_statuses WHERE code = 'PENDING' AND is_active IS TRUE LIMIT 1;
  IF v_pending_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status PENDING'; END IF;

  SELECT id INTO v_case_reassigned_stage_id FROM public.case_stages WHERE code = 'CASE_REASSIGNED' AND is_active IS TRUE LIMIT 1;
  IF v_case_reassigned_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage CASE_REASSIGNED'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = p_new_prosecutor_id) THEN RAISE EXCEPTION 'Unknown prosecutor id %', p_new_prosecutor_id; END IF;
  IF p_new_staff_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.staff WHERE id = p_new_staff_id) THEN RAISE EXCEPTION 'Unknown staff id %', p_new_staff_id; END IF;

  SELECT cpd.current_status_id, cpd.current_case_status_id, cpd.current_case_stage_id, to_jsonb(cpd)
  INTO v_previous_status_id, v_previous_case_status_id, v_previous_stage_id, v_old_details
  FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  SELECT ca.id, ca.prosecutor_id, ca.staff_id, to_jsonb(ca), COALESCE(p.short_name, p.full_name)
  INTO v_previous_assignment_id, v_previous_prosecutor_id, v_previous_staff_id, v_previous_assignment_old, v_previous_prosecutor_name
  FROM public.case_assignments ca
  LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
  WHERE ca.case_id = p_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE
  ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
  LIMIT 1
  FOR UPDATE OF ca;

  IF v_previous_assignment_id IS NULL THEN RAISE EXCEPTION 'This case has no active assignment to reassign.'; END IF;

  v_reassigned_at := (p_reassignment_date::timestamp + COALESCE(p_reassignment_time, '00:00'::time))::timestamptz;

  SELECT COALESCE(short_name, full_name) INTO v_new_prosecutor_name FROM public.prosecutors WHERE id = p_new_prosecutor_id;
  SELECT COALESCE(short_name, full_name) INTO v_staff_name FROM public.staff WHERE id = p_new_staff_id;

  UPDATE public.case_assignments
  SET unassigned_at = v_reassigned_at, unassigned_by_user_id = p_user_id, unassignment_reason = v_reason
  WHERE id = v_previous_assignment_id;

  SELECT to_jsonb(ca) INTO v_previous_assignment_new FROM public.case_assignments ca WHERE ca.id = v_previous_assignment_id;

  INSERT INTO public.case_assignments (case_id, prosecutor_id, staff_id, assigned_by_user_id, assigned_at, remarks)
  VALUES (p_case_id, p_new_prosecutor_id, p_new_staff_id, p_user_id, v_reassigned_at, v_remarks)
  RETURNING id INTO v_new_assignment_id;

  INSERT INTO public.case_events (
    case_id, event_type_id, event_date, event_time, title, description,
    status_id, case_status_id, case_stage_id,
    prosecutor_id, staff_id, details_jsonb, source, source_table, source_id,
    created_by_user_id, updated_by_user_id
  ) VALUES (
    p_case_id, v_event_type_id, p_reassignment_date, p_reassignment_time,
    'Case Reassignment',
    'Reassigned from Prosec ' || COALESCE(v_previous_prosecutor_name, v_previous_prosecutor_id::text) || ' to Prosec ' || COALESCE(v_new_prosecutor_name, p_new_prosecutor_id::text) || ' on ' || to_char(p_reassignment_date, 'Mon FMDD, YYYY'),
    v_pending_status_id, v_pending_status_id, v_case_reassigned_stage_id,
    p_new_prosecutor_id, p_new_staff_id,
    jsonb_build_object(
      'action', 'case_reassignment',
      'previous_assignment_id', v_previous_assignment_id,
      'previous_prosecutor_id', v_previous_prosecutor_id,
      'previous_prosecutor_name', v_previous_prosecutor_name,
      'new_assignment_id', v_new_assignment_id,
      'new_prosecutor_id', p_new_prosecutor_id,
      'new_prosecutor_name', v_new_prosecutor_name,
      'staff_id', p_new_staff_id,
      'staff_name', v_staff_name,
      'reassignment_date', p_reassignment_date,
      'reassignment_time', p_reassignment_time,
      'reason', v_reason,
      'remarks', v_remarks,
      'automatic_case_status', 'Pending',
      'automatic_case_stage', 'Case Reassigned'
    ),
    'MANUAL_ENTRY', 'case_assignments', v_new_assignment_id, p_user_id, p_user_id
  ) RETURNING id INTO v_event_id;

  UPDATE public.case_assignments SET case_event_id = v_event_id WHERE id = v_new_assignment_id;

  INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
  VALUES (p_case_id,COALESCE(v_previous_case_status_id, v_previous_status_id),v_pending_status_id,p_user_id,now(),p_reassignment_date,v_remarks,v_event_id)
  RETURNING id INTO v_status_history_id;

  INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id)
  VALUES (p_case_id,v_previous_stage_id,v_case_reassigned_stage_id,p_user_id,now(),p_reassignment_date,v_remarks,v_event_id)
  RETURNING id INTO v_stage_history_id;

  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_case_status_id,current_case_status_date,current_case_stage_id,current_case_stage_date,updated_at)
  VALUES (p_case_id,v_pending_status_id,p_reassignment_date,v_pending_status_id,p_reassignment_date,v_case_reassigned_stage_id,p_reassignment_date,now())
  ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_status_remarks=NULL,current_case_stage_remarks=NULL,updated_at=now();

  SELECT to_jsonb(ca) INTO v_new_assignment_new FROM public.case_assignments ca WHERE ca.id = v_new_assignment_id;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES
    (p_user_id, 'case_assignments', v_previous_assignment_id, 'CASE_REASSIGNMENT_OLD_ASSIGNMENT_CLOSED', v_previous_assignment_old, v_previous_assignment_new, p_case_id, 'Closed old assignment during case reassignment.', jsonb_build_object('case_event_id', v_event_id, 'reason', v_reason, 'new_assignment_id', v_new_assignment_id)),
    (p_user_id, 'case_assignments', v_new_assignment_id, 'CASE_REASSIGNMENT_NEW_ASSIGNMENT_CREATED', NULL, v_new_assignment_new, p_case_id, 'Created new assignment during case reassignment.', jsonb_build_object('case_event_id', v_event_id, 'reason', v_reason, 'previous_assignment_id', v_previous_assignment_id, 'case_status_id', v_pending_status_id, 'case_stage_id', v_case_reassigned_stage_id, 'status_history_id', v_status_history_id, 'case_stage_history_id', v_stage_history_id, 'case_private_details', v_new_details));

  RETURN v_event_id;
END;
$$;


--
-- Name: record_case_resolved_event(bigint, text, date, time without time zone, text, jsonb, jsonb, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_case_resolved_event(p_case_id bigint, p_recommendation_code text, p_date_resolved date, p_time_resolved time without time zone DEFAULT NULL::time without time zone, p_remarks text DEFAULT NULL::text, p_charges_for_filing jsonb DEFAULT '[]'::jsonb, p_charges_for_dismissal jsonb DEFAULT '[]'::jsonb, p_user_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_event_type_id bigint;
  v_reso_for_approval_status_id bigint;
  v_previous_status_id bigint;
  v_event_id bigint;
  v_resolution_id bigint;
  v_status_history_id bigint;
  v_recommendation_label text;
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
  v_old_details jsonb;
  v_new_details jsonb;
  v_charge jsonb;
  v_display_order integer;
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_recommendation_code NOT IN ('CASE_FOR_FILING', 'CASE_DISMISSAL', 'MIXED_RESULT') THEN RAISE EXCEPTION 'Recommendation is required'; END IF;
  IF p_date_resolved IS NULL THEN RAISE EXCEPTION 'Date resolved is required'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
  VALUES ('CASE_RESOLVED', 'Case Resolved', 'CASE', 'Manual timeline event for resolving a case.', 120, true, true)
  ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, category = EXCLUDED.category, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, is_active = true, updated_at = now()
  RETURNING id INTO v_event_type_id;

  INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active)
  VALUES ('RESO_FOR_APPROVAL', 'Reso for Approval', 80, false, true, true)
  ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, sort_order = EXCLUDED.sort_order, is_final = false, is_milestone = true, is_active = true
  RETURNING id INTO v_reso_for_approval_status_id;

  v_recommendation_label := CASE p_recommendation_code
    WHEN 'CASE_FOR_FILING' THEN 'Case for Filing'
    WHEN 'CASE_DISMISSAL' THEN 'Case Dismissal'
    ELSE 'Mixed Result'
  END;

  SELECT cpd.current_status_id, to_jsonb(cpd)
  INTO v_previous_status_id, v_old_details
  FROM public.case_private_details cpd
  WHERE cpd.case_id = p_case_id;

  INSERT INTO public.case_events (
    case_id, event_type_id, event_date, event_time, title, description, status_id,
    details_jsonb, source, created_by_user_id, updated_by_user_id
  ) VALUES (
    p_case_id, v_event_type_id, p_date_resolved, p_time_resolved, 'Case Resolved',
    'Case resolved as ' || v_recommendation_label || ' on ' || to_char(p_date_resolved, 'Mon FMDD, YYYY'),
    v_reso_for_approval_status_id,
    jsonb_build_object('recommendation_code', p_recommendation_code, 'recommendation_label', v_recommendation_label, 'remarks', v_remarks),
    'MANUAL_ENTRY', p_user_id, p_user_id
  ) RETURNING id INTO v_event_id;

  INSERT INTO public.case_resolutions (case_id, case_event_id, recommendation_code, date_resolved, time_resolved, remarks, created_by_user_id, updated_by_user_id)
  VALUES (p_case_id, v_event_id, p_recommendation_code, p_date_resolved, p_time_resolved, v_remarks, p_user_id, p_user_id)
  RETURNING id INTO v_resolution_id;

  IF p_recommendation_code IN ('CASE_FOR_FILING', 'MIXED_RESULT') THEN
    v_display_order := 0;
    FOR v_charge IN SELECT * FROM jsonb_array_elements(COALESCE(p_charges_for_filing, '[]'::jsonb)) LOOP
      v_display_order := v_display_order + 1;
      IF NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), '') IS NOT NULL THEN
        INSERT INTO public.case_resolution_charge_actions (case_resolution_id, case_id, case_violation_id, violation_id, charge_text, action_code, display_order, remarks)
        VALUES (v_resolution_id, p_case_id, NULLIF(v_charge->>'case_violation_id', '')::bigint, NULLIF(v_charge->>'violation_id', '')::bigint, NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), ''), 'FOR_FILING', v_display_order, NULLIF(btrim(COALESCE(v_charge->>'remarks', '')), ''));
      END IF;
    END LOOP;
  END IF;

  IF p_recommendation_code IN ('CASE_DISMISSAL', 'MIXED_RESULT') THEN
    v_display_order := 0;
    FOR v_charge IN SELECT * FROM jsonb_array_elements(COALESCE(p_charges_for_dismissal, '[]'::jsonb)) LOOP
      v_display_order := v_display_order + 1;
      IF NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), '') IS NOT NULL THEN
        INSERT INTO public.case_resolution_charge_actions (case_resolution_id, case_id, case_violation_id, violation_id, charge_text, action_code, display_order, remarks)
        VALUES (v_resolution_id, p_case_id, NULLIF(v_charge->>'case_violation_id', '')::bigint, NULLIF(v_charge->>'violation_id', '')::bigint, NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), ''), 'DISMISSAL', v_display_order, NULLIF(btrim(COALESCE(v_charge->>'remarks', '')), ''));
      END IF;
    END LOOP;
  END IF;

  UPDATE public.case_events
  SET source_table = 'case_resolutions',
      source_id = v_resolution_id,
      details_jsonb = details_jsonb || jsonb_build_object(
        'charge_actions',
        COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'id', cra.id,
            'action_code', cra.action_code,
            'charge_text', cra.charge_text,
            'display_order', cra.display_order,
            'remarks', cra.remarks
          ) ORDER BY cra.action_code, cra.display_order, cra.id)
          FROM public.case_resolution_charge_actions cra
          WHERE cra.case_resolution_id = v_resolution_id
        ), '[]'::jsonb)
      ),
      updated_by_user_id = p_user_id,
      updated_at = now()
  WHERE id = v_event_id;

  INSERT INTO public.case_private_details (case_id, current_status_id, current_status_date, current_status_remarks, updated_at)
  VALUES (p_case_id, v_reso_for_approval_status_id, p_date_resolved, v_remarks, now())
  ON CONFLICT (case_id) DO UPDATE SET
    current_status_id = EXCLUDED.current_status_id,
    current_status_date = EXCLUDED.current_status_date,
    current_status_remarks = EXCLUDED.current_status_remarks,
    updated_at = now();

  INSERT INTO public.case_status_history (case_id, from_status_id, to_status_id, changed_by_user_id, changed_at, status_date, remarks, case_event_id)
  VALUES (p_case_id, v_previous_status_id, v_reso_for_approval_status_id, p_user_id, now(), p_date_resolved, v_remarks, v_event_id)
  RETURNING id INTO v_status_history_id;

  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (p_user_id, 'case_resolutions', v_resolution_id, 'CASE_RESOLVED', v_old_details, v_new_details, p_case_id, 'Case resolved as ' || v_recommendation_label || '.', jsonb_build_object('case_event_id', v_event_id, 'status_history_id', v_status_history_id, 'recommendation_code', p_recommendation_code));

  RETURN v_event_id;
END;
$$;


--
-- Name: record_court_filing_event(bigint, bigint, bigint, text, text, text, date, time without time zone, integer, text, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_court_filing_event(p_case_id bigint, p_case_resolution_approval_action_id bigint, p_court_id bigint DEFAULT NULL::bigint, p_court_name text DEFAULT NULL::text, p_court_branch text DEFAULT NULL::text, p_charge_filed text DEFAULT NULL::text, p_date_filed date DEFAULT NULL::date, p_time_filed time without time zone DEFAULT NULL::time without time zone, p_information_count integer DEFAULT NULL::integer, p_criminal_case_no text DEFAULT NULL::text, p_remarks text DEFAULT NULL::text, p_user_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_filing_id bigint; v_approval_id bigint; v_resolution_id bigint;
  v_status_code text; v_status_label text; v_status_id bigint; v_prev_status_id bigint; v_status_history_id bigint;
  v_old_details jsonb; v_new_details jsonb; v_court_id bigint; v_court_name text; v_court_code text; v_court_code_candidate text; v_code_suffix integer := 0; v_charge text := NULLIF(btrim(COALESCE(p_charge_filed, '')), '');
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_case_resolution_approval_action_id IS NULL THEN RAISE EXCEPTION 'Approved filing decision is required'; END IF;
  IF p_court_id IS NULL AND NULLIF(btrim(COALESCE(p_court_name, '')), '') IS NULL THEN RAISE EXCEPTION 'Court is required'; END IF;
  IF v_charge IS NULL THEN RAISE EXCEPTION 'Charge filed is required'; END IF;
  IF p_date_filed IS NULL THEN RAISE EXCEPTION 'Date filed is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;

  SELECT aa.approval_id, a.case_resolution_id INTO v_approval_id, v_resolution_id
  FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a ON a.id = aa.approval_id
  JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id
  WHERE aa.id = p_case_resolution_approval_action_id AND aa.case_id = p_case_id
    AND aa.decision_code = 'FOR_FILING' AND a.is_voided = false AND cr.is_voided = false;
  IF v_approval_id IS NULL THEN RAISE EXCEPTION 'No active approved FOR_FILING decision was found for this case.'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_court_filings WHERE case_resolution_approval_action_id = p_case_resolution_approval_action_id AND is_voided = false) THEN
    RAISE EXCEPTION 'This approved filing decision already has a court filing.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_resolution_approval_actions aa JOIN public.case_resolution_approvals a ON a.id=aa.approval_id JOIN public.case_resolutions cr ON cr.id=a.case_resolution_id WHERE aa.case_id=p_case_id AND aa.decision_code='FOR_FILING' AND a.is_voided=false AND cr.is_voided=false) THEN
    RAISE EXCEPTION 'No active approved FOR_FILING decision was found for this case.';
  END IF;

  IF p_court_id IS NOT NULL THEN
    SELECT c.id, c.name INTO v_court_id, v_court_name
    FROM public.courts c
    WHERE c.id = p_court_id;
    IF v_court_id IS NULL THEN RAISE EXCEPTION 'Unknown court id %', p_court_id; END IF;
  ELSE
    SELECT c.id, c.name INTO v_court_id, v_court_name
    FROM public.courts c
    WHERE lower(btrim(c.name)) = lower(btrim(p_court_name))
    ORDER BY c.id
    LIMIT 1;

    IF v_court_id IS NULL THEN
      v_court_name := NULLIF(btrim(p_court_name), '');
      v_court_code_candidate := upper(regexp_replace(v_court_name, '[^a-zA-Z0-9]+', '_', 'g'));
      v_court_code_candidate := trim(both '_' FROM COALESCE(NULLIF(v_court_code_candidate, ''), 'COURT'));
      v_court_code := left(v_court_code_candidate, 64);
      WHILE EXISTS (SELECT 1 FROM public.courts WHERE code = v_court_code) LOOP
        v_code_suffix := v_code_suffix + 1;
        v_court_code := left(v_court_code_candidate, greatest(1, 63 - length(v_code_suffix::text))) || '_' || v_code_suffix::text;
      END LOOP;
      INSERT INTO public.courts(code, name, court_type, is_active)
      VALUES (v_court_code, v_court_name, NULL, true)
      RETURNING id, name INTO v_court_id, v_court_name;
    END IF;
  END IF;

  INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active) VALUES ('COURT_FILING','Court Filing','COURT','Manual timeline event for recording filing in court.',140,true,true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,is_active=true,updated_at=now() RETURNING id INTO v_event_type_id;

  SELECT current_status_id, to_jsonb(cpd) INTO v_prev_status_id, v_old_details FROM public.case_private_details cpd WHERE case_id=p_case_id;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,details_jsonb,source,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_filed,p_time_filed,'Court Filing','Filed in ' || v_court_name || ' on ' || to_char(p_date_filed, 'Mon FMDD, YYYY'),NULL,
    jsonb_build_object('court',v_court_name,'court_id',v_court_id,'court_branch',NULLIF(btrim(COALESCE(p_court_branch,'')),''),'charge_filed',v_charge,'date_filed',p_date_filed,'time_filed',p_time_filed,'information_count',p_information_count,'criminal_case_no',NULLIF(btrim(COALESCE(p_criminal_case_no,'')),''),'remarks',NULLIF(btrim(COALESCE(p_remarks,'')),''),'case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id),
    'MANUAL_ENTRY',p_user_id,p_user_id) RETURNING id INTO v_event_id;

  INSERT INTO public.case_court_filings(case_id,case_event_id,case_resolution_approval_id,case_resolution_approval_action_id,court_id,court_name,court_branch,charge_filed,date_filed,time_filed,information_count,criminal_case_no,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_id,v_approval_id,p_case_resolution_approval_action_id,v_court_id,v_court_name,NULLIF(btrim(COALESCE(p_court_branch,'')),''),v_charge,p_date_filed,p_time_filed,p_information_count,NULLIF(btrim(COALESCE(p_criminal_case_no,'')),''),NULLIF(btrim(COALESCE(p_remarks,'')),''),p_user_id,p_user_id) RETURNING id INTO v_filing_id;

  UPDATE public.case_events SET source_table='case_court_filings', source_id=v_filing_id, updated_at=now(), updated_by_user_id=p_user_id WHERE id=v_event_id;

  SELECT status_code, status_label INTO v_status_code, v_status_label FROM public.recompute_case_status_after_court_filing(p_case_id) LIMIT 1;
  IF v_status_code IS NOT NULL THEN
    INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active) VALUES (v_status_code, v_status_label, CASE v_status_code WHEN 'PENDING' THEN 20 WHEN 'RESO_FOR_APPROVAL' THEN 80 WHEN 'FOR_FILING' THEN 90 WHEN 'FILED_OTHER_RESO_FOR_APPROVAL' THEN 92 WHEN 'FILED_OTHER_INFO_FOR_FILING' THEN 94 WHEN 'FILED' THEN 96 WHEN 'DISMISSED' THEN 100 ELSE 110 END, v_status_code IN ('FILED','DISMISSED','MIXED_RESULT'), v_status_code <> 'PENDING', true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,sort_order=EXCLUDED.sort_order,is_final=EXCLUDED.is_final,is_milestone=EXCLUDED.is_milestone,is_active=true RETURNING id INTO v_status_id;
    UPDATE public.case_events SET status_id=v_status_id, updated_at=now(), updated_by_user_id=p_user_id WHERE id=v_event_id;
    INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,updated_at) VALUES (p_case_id,v_status_id,p_date_filed,NULLIF(btrim(COALESCE(p_remarks,'')),''),now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,updated_at=now();
  END IF;
  IF v_prev_status_id IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,v_prev_status_id,v_status_id,p_user_id,now(),p_date_filed,'Court filing recorded. Status recomputed.',v_event_id) RETURNING id INTO v_status_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_court_filings',v_filing_id,'COURT_FILING',v_old_details,v_new_details,p_case_id,'Court filing recorded.',jsonb_build_object('case_event_id',v_event_id,'status_history_id',v_status_history_id,'case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id));
  RETURN v_event_id;
END;
$$;


--
-- Name: refresh_clearance_phonetic_name_tokens(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_clearance_phonetic_name_tokens() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  truncate table public.clearance_phonetic_name_tokens;

  insert into public.clearance_phonetic_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, phonetic_primary, phonetic_alt, phonetic_codes)
  select x.person_id, x.organization_id, x.source_table, x.source_column, x.source_value,
    tok.token, tok.token_order::integer, length(tok.token), dmetaphone(tok.token), dmetaphone_alt(tok.token), public.clearance_phonetic_codes(tok.token)
  from (
    select p.id as person_id, null::integer as organization_id, 'persons' as source_table, 'full_name' as source_column, p.full_name as source_value from public.persons p where coalesce(p.is_active, true) = true
    union all select pa.person_id, null::integer, 'person_aliases', 'alias_name', pa.alias_name from public.person_aliases pa join public.persons p on p.id = pa.person_id where coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true
    union all select null::integer, o.id, 'organizations', 'organization_name', o.organization_name from public.organizations o where coalesce(o.is_active, true) = true
    union all select null::integer, oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name from public.organization_aliases oa join public.organizations o on o.id = oa.organization_id where coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true
  ) x
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order)
  where length(tok.token) > 1 and cardinality(public.clearance_phonetic_codes(tok.token)) > 0;
end;
$$;


--
-- Name: refresh_clearance_possible_name_tokens(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_clearance_possible_name_tokens() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  truncate table public.clearance_possible_name_tokens;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select p.id, null::integer, 'persons', 'full_name', p.full_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.persons p
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(p.full_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(p.is_active, true) = true and length(tok.token) > 1;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select pa.person_id, null::integer, 'person_aliases', 'alias_name', pa.alias_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.person_aliases pa
  join public.persons p on p.id = pa.person_id
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(pa.alias_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true and length(tok.token) > 1;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select null::integer, o.id, 'organizations', 'organization_name', o.organization_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.organizations o
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(o.organization_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(o.is_active, true) = true and length(tok.token) > 1;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select null::integer, oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.organization_aliases oa
  join public.organizations o on o.id = oa.organization_id
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(oa.alias_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true and length(tok.token) > 1;
end;
$$;


--
-- Name: search_clearance_exact_candidates(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_exact_candidates(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, organization_id integer, participant_kind text, confidence_score integer, match_details text, match_type text, match_source text, result_group text, correction_id bigint, full_name text, aliases text[], is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamp with time zone, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb)
    LANGUAGE sql STABLE
    AS $$
  with n as (
    select nullif(trim(p_query),'') q, public.clearance_exact_norm(p_query) q_norm, public.clearance_exact_tokens(p_query) q_tokens,
      cardinality(public.clearance_exact_tokens(p_query)) q_count,
      case when p_search_type in ('name','alias','all') then p_search_type else 'all' end st,
      least(greatest(coalesce(p_limit,50),1),100) lim
  ), parties as (
    select p.id::integer person_id, null::integer organization_id, 'PERSON'::text participant_kind,
      p.full_name official_name, p.full_name search_name,
      public.clearance_exact_norm(p.full_name) name_norm, public.clearance_exact_tokens(p.full_name) name_tokens,
      coalesce(a.aliases, array[]::text[]) aliases, coalesce(a.alias_full,false) alias_full, coalesce(a.alias_tokens,false) alias_tokens, coalesce(a.alias_single,false) alias_single, a.best_alias,
      false is_voided, false is_corrected, null::integer replaced_by_person_id, p.id::integer active_person_id,
      null::bigint correction_id, null::text correction_reason, null::timestamptz corrected_at, null::text corrected_by,
      null::jsonb old_snapshot_json, null::jsonb new_snapshot_json, 'active'::text result_group, 'active_name'::text match_source
    from n join public.persons p on n.q is not null and coalesce(p.is_active,true) and not coalesce(p.is_voided,false)
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases, bool_or(public.clearance_exact_norm(pa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(pa.alias_name) && n.q_tokens) alias_single, (array_agg(pa.alias_name order by case when public.clearance_exact_norm(pa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) then 2 else 3 end, pa.alias_name))[1] best_alias from public.person_aliases pa where pa.person_id=p.id and coalesce(pa.is_active,true)) a on true

    union all
    select oldp.id::integer, null::integer, 'PERSON'::text,
      oldp.full_name, oldp.full_name,
      public.clearance_exact_norm(oldp.full_name), public.clearance_exact_tokens(oldp.full_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      coalesce(oldp.is_voided,false), cpc.id is not null, oldp.replaced_by_person_id::integer, coalesce(oldp.replaced_by_person_id, cpc.new_person_id, oldp.id)::integer,
      cpc.id, coalesce(cpc.reason, oldp.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'inactive'::text, 'voided_previous_name'::text
    from n join public.persons oldp on n.q is not null and (coalesce(oldp.is_voided,false) or not coalesce(oldp.is_active,true))
    left join public.case_participant_corrections cpc on cpc.old_person_id = oldp.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases, bool_or(public.clearance_exact_norm(pa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(pa.alias_name) && n.q_tokens) alias_single, (array_agg(pa.alias_name order by case when public.clearance_exact_norm(pa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) then 2 else 3 end, pa.alias_name))[1] best_alias from public.person_aliases pa where pa.person_id=oldp.id and coalesce(pa.is_active,true)) a on true

    union all
    select newp.id::integer, null::integer, 'PERSON'::text,
      newp.full_name, oldp.full_name,
      public.clearance_exact_norm(oldp.full_name), public.clearance_exact_tokens(oldp.full_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      false, true, oldp.replaced_by_person_id::integer, newp.id::integer,
      cpc.id, coalesce(cpc.reason, oldp.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'active'::text, 'voided_previous_name'::text
    from n
    join public.persons oldp on n.q is not null and coalesce(oldp.is_voided,false) and oldp.replaced_by_person_id is not null
    join public.persons newp on newp.id = oldp.replaced_by_person_id and coalesce(newp.is_active,true) and not coalesce(newp.is_voided,false)
    left join public.case_participant_corrections cpc on cpc.old_person_id = oldp.id and cpc.new_person_id = newp.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases, bool_or(public.clearance_exact_norm(pa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(pa.alias_name) && n.q_tokens) alias_single, (array_agg(pa.alias_name order by case when public.clearance_exact_norm(pa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) then 2 else 3 end, pa.alias_name))[1] best_alias from public.person_aliases pa where pa.person_id=newp.id and coalesce(pa.is_active,true)) a on true

    union all
    select null::integer, o.id::integer, 'ORGANIZATION'::text, o.organization_name, o.organization_name,
      public.clearance_exact_norm(o.organization_name), public.clearance_exact_tokens(o.organization_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      false, false, null::integer, null::integer, null::bigint, null::text, null::timestamptz, null::text, null::jsonb, null::jsonb, 'active'::text, 'active_name'::text
    from n join public.organizations o on n.q is not null and coalesce(o.is_active,true) and not coalesce(o.is_voided,false)
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases, bool_or(public.clearance_exact_norm(oa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(oa.alias_name) && n.q_tokens) alias_single, (array_agg(oa.alias_name order by case when public.clearance_exact_norm(oa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name) then 2 else 3 end, oa.alias_name))[1] best_alias from public.organization_aliases oa where oa.organization_id=o.id and coalesce(oa.is_active,true)) a on true

    union all
    select null::integer, oldo.id::integer, 'ORGANIZATION'::text, oldo.organization_name, oldo.organization_name,
      public.clearance_exact_norm(oldo.organization_name), public.clearance_exact_tokens(oldo.organization_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      coalesce(oldo.is_voided,false), cpc.id is not null, null::integer, null::integer,
      cpc.id, coalesce(cpc.reason, oldo.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'inactive'::text, 'voided_previous_name'::text
    from n join public.organizations oldo on n.q is not null and (coalesce(oldo.is_voided,false) or not coalesce(oldo.is_active,true))
    left join public.case_participant_corrections cpc on cpc.old_organization_id = oldo.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases, bool_or(public.clearance_exact_norm(oa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(oa.alias_name) && n.q_tokens) alias_single, (array_agg(oa.alias_name order by case when public.clearance_exact_norm(oa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name) then 2 else 3 end, oa.alias_name))[1] best_alias from public.organization_aliases oa where oa.organization_id=oldo.id and coalesce(oa.is_active,true)) a on true

    union all
    select null::integer, newo.id::integer, 'ORGANIZATION'::text, newo.organization_name, oldo.organization_name,
      public.clearance_exact_norm(oldo.organization_name), public.clearance_exact_tokens(oldo.organization_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      false, true, null::integer, null::integer,
      cpc.id, coalesce(cpc.reason, oldo.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'active'::text, 'voided_previous_name'::text
    from n
    join public.organizations oldo on n.q is not null and coalesce(oldo.is_voided,false) and oldo.replaced_by_organization_id is not null
    join public.organizations newo on newo.id = oldo.replaced_by_organization_id and coalesce(newo.is_active,true) and not coalesce(newo.is_voided,false)
    left join public.case_participant_corrections cpc on cpc.old_organization_id = oldo.id and cpc.new_organization_id = newo.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases, bool_or(public.clearance_exact_norm(oa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(oa.alias_name) && n.q_tokens) alias_single, (array_agg(oa.alias_name order by case when public.clearance_exact_norm(oa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name) then 2 else 3 end, oa.alias_name))[1] best_alias from public.organization_aliases oa where oa.organization_id=newo.id and coalesce(oa.is_active,true)) a on true
  ), scored as (
    select *, case when st in ('name','all') and name_norm=q_norm then 100 when st in ('name','all') and q_count>=2 and q_tokens <@ name_tokens then 95 when st in ('alias','all') and alias_full then 92 when st in ('alias','all') and q_count>=2 and alias_tokens then 88 when st in ('alias','all') and q_count=1 and alias_single then 72 when st in ('name','all') and q_count=1 and name_tokens && q_tokens then 65 else 0 end score
    from parties join n on true
  ), deduped as (
    select distinct on (result_group, person_id, organization_id, match_source, correction_id)
      person_id, organization_id, participant_kind, score confidence_score,
      case when match_source = 'voided_previous_name' and result_group = 'active' then 'Matched previous corrected name: ' || search_name when match_source = 'voided_previous_name' then 'Matched voided/corrected previous name' when st in ('name','all') and name_norm=q_norm then 'Exact normalized name match' when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'Exact alias match: '||coalesce(best_alias,'') else 'Exact token match' end match_details,
      case when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'alias' else 'exact' end match_type,
      match_source, result_group, correction_id, official_name full_name, aliases, is_voided, is_corrected, replaced_by_person_id, active_person_id, correction_reason, corrected_at, corrected_by, old_snapshot_json, new_snapshot_json
    from scored where score>0
    order by result_group, person_id nulls last, organization_id nulls last, match_source, correction_id nulls last, score desc
  )
  select * from deduped order by case when result_group='active' then 0 else 1 end, confidence_score desc, full_name limit least(greatest(coalesce(p_limit,50),1),100);
$$;


--
-- Name: search_clearance_phonetic_matches(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_phonetic_matches(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text, is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamp with time zone, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text)
    LANGUAGE sql STABLE
    AS $$
  with q as (
    select public.clearance_phonetic_codes(tok) codes from regexp_split_to_table(public.clearance_exact_norm(p_query), ' ') tok where length(tok) > 1
  ), hits as materialized (
    select distinct t.person_id, t.organization_id
    from public.clearance_phonetic_name_tokens t join q on t.phonetic_codes && q.codes
    limit least(greatest(coalesce(p_limit, 50), 1), 100) * 3
  ), candidates as (
    select h.person_id, h.organization_id, case when h.organization_id is not null then 'ORGANIZATION' else 'PERSON' end participant_kind,
      62::integer confidence_score, 'Sound-alike phonetic token match'::text match_details, 'phonetic'::text match_type, 'phonetic'::text match_source,
      case when coalesce(p.is_voided, o.is_voided, false) or not coalesce(p.is_active, o.is_active, true) then 'inactive' else 'active' end result_group,
      null::bigint correction_id, coalesce(p.full_name, o.organization_name) full_name, coalesce(pa.aliases, oa.aliases, array[]::text[]) aliases,
      coalesce(p.is_voided, o.is_voided, false) is_voided, false is_corrected, p.replaced_by_person_id::integer, coalesce(p.replaced_by_person_id, p.id)::integer active_person_id,
      coalesce(p.void_reason, o.void_reason) correction_reason, null::timestamptz corrected_at, null::text corrected_by, null::jsonb old_snapshot_json, null::jsonb new_snapshot_json
    from hits h
    left join public.persons p on p.id = h.person_id
    left join public.organizations o on o.id = h.organization_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases from public.person_aliases pa where pa.person_id = h.person_id and coalesce(pa.is_active, true)) pa on true
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases from public.organization_aliases oa where oa.organization_id = h.organization_id and coalesce(oa.is_active, true)) oa on true
  )
  select * from public.format_clearance_search_results((select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) from candidates c), p_limit);
$$;


--
-- Name: search_clearance_possible_matches(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_possible_matches(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text, is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamp with time zone, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text)
    LANGUAGE sql STABLE
    AS $$ select * from public.search_clearance_possible_matches_v31(p_query,p_search_type,p_limit); $$;


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

CREATE FUNCTION public.search_clearance_possible_matches_v31(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text, is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamp with time zone, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text)
    LANGUAGE sql STABLE
    AS $$
  with normalized as (
    select nullif(trim(p_query), '') q, public.clearance_exact_tokens(p_query) q_tokens, cardinality(public.clearance_exact_tokens(p_query)) q_token_count, case when p_search_type in ('name', 'alias', 'all') then p_search_type else 'all' end search_type, least(greatest(coalesce(p_limit, 50), 1), 100) safe_limit
  ), query_tokens as (
    select u.token, length(u.token) token_len, left(u.token, 1) first_char, left(u.token, 2) first2, right(u.token, 2) last2, public.clearance_ck_key(u.token) ck_key, public.clearance_bv_key(u.token) bv_key, public.clearance_phf_key(u.token) phf_key, public.clearance_sz_key(u.token) sz_key, public.clearance_token_skeleton(u.token) skeleton
    from normalized n cross join lateral unnest(n.q_tokens) u(token)
  ), raw_token_candidates as materialized (
    select t.person_id, t.organization_id, t.source_value, t.source_table, q.token query_token,
      case when t.token = q.token then 'exact' when t.ck_key = q.ck_key then 'c/k variant' when t.bv_key = q.bv_key then 'b/v variant' when t.phf_key = q.phf_key then 'ph/f variant' when t.sz_key = q.sz_key then 's/z variant' when t.skeleton = q.skeleton then 'skeleton variant' else 'fuzzy' end raw_reason,
      case when t.token = q.token then 1 when t.ck_key = q.ck_key or t.bv_key = q.bv_key or t.phf_key = q.phf_key or t.sz_key = q.sz_key then 2 when t.skeleton = q.skeleton then 3 else 4 end raw_priority
    from query_tokens q
    join public.clearance_possible_name_tokens t on (t.token = q.token or t.ck_key = q.ck_key or t.bv_key = q.bv_key or t.phf_key = q.phf_key or t.sz_key = q.sz_key or (q.token_len >= 4 and t.token_len >= 4 and t.skeleton = q.skeleton) or (q.token_len >= 4 and t.token_len >= 4 and t.first2 = q.first2 and t.last2 = q.last2) or (q.token_len >= 5 and t.token_len >= 5 and t.first_char = q.first_char and levenshtein_less_equal(t.token, q.token, 2) <= 2))
    join normalized n on true
    where n.q is not null and (n.search_type = 'all' or (n.search_type = 'name' and t.source_table in ('persons', 'organizations')) or (n.search_type = 'alias' and t.source_table in ('person_aliases', 'organization_aliases')))
  ), entity_candidates as materialized (
    select person_id, organization_id, min(raw_priority) best_priority, count(distinct query_token) matched_query_tokens, (array_agg(source_value order by raw_priority, source_value))[1] best_source_value, string_agg(distinct raw_reason, ', ' order by raw_reason) reasons
    from raw_token_candidates group by person_id, organization_id
    order by min(raw_priority), count(distinct query_token) desc
    limit (select safe_limit * 3 from normalized)
  ), fuzzy_candidates as (
    select ec.person_id, ec.organization_id, case when ec.organization_id is not null then 'ORGANIZATION' else 'PERSON' end participant_kind,
      greatest(55, least(89, 58 + case when ec.matched_query_tokens >= (select q_token_count from normalized) and (select q_token_count from normalized) >= 2 then 18 else 0 end + case ec.best_priority when 1 then 10 when 2 then 8 when 3 then 6 else 3 end + least(8, ec.matched_query_tokens * 2)))::integer confidence_score,
      'Possible fuzzy token match (' || ec.reasons || '): ' || coalesce(ec.best_source_value, p.full_name, o.organization_name) match_details,
      case when ec.best_priority <= 2 then 'variant' else 'fuzzy' end match_type,
      case when ec.best_priority <= 2 then 'possible_variant' else 'possible_fuzzy' end match_source,
      case when coalesce(p.is_voided, o.is_voided, false) or not coalesce(p.is_active, o.is_active, true) then 'inactive' else 'active' end result_group,
      null::bigint correction_id, coalesce(p.full_name, o.organization_name, ec.best_source_value) full_name,
      coalesce(pa.aliases, oa.aliases, array[]::text[]) aliases, coalesce(p.is_voided, o.is_voided, false) is_voided, false is_corrected, p.replaced_by_person_id::integer, coalesce(p.replaced_by_person_id, p.id)::integer active_person_id,
      coalesce(p.void_reason, o.void_reason) correction_reason, null::timestamptz corrected_at, null::text corrected_by, null::jsonb old_snapshot_json, null::jsonb new_snapshot_json
    from entity_candidates ec
    left join public.persons p on p.id = ec.person_id
    left join public.organizations o on o.id = ec.organization_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases from public.person_aliases pa where pa.person_id = ec.person_id and coalesce(pa.is_active, true)) pa on true
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases from public.organization_aliases oa where oa.organization_id = ec.organization_id and coalesce(oa.is_active, true)) oa on true
    where ec.matched_query_tokens > 0
  ), combined as (
    select * from public.search_clearance_exact_candidates(p_query, p_search_type, (select safe_limit from normalized))
    union all select * from fuzzy_candidates
  )
  select * from public.format_clearance_search_results((select coalesce(jsonb_agg(to_jsonb(c) order by confidence_score desc), '[]'::jsonb) from combined c), (select safe_limit from normalized));
$$;


--
-- Name: search_clearance_records(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_records(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text, is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamp with time zone, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text)
    LANGUAGE sql STABLE
    AS $$
  select * from public.format_clearance_search_results(
    (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) from public.search_clearance_exact_candidates(p_query, p_search_type, least(greatest(coalesce(p_limit, 50), 1), 100)) c),
    p_limit
  );
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
-- Name: upsert_clearance_phonetic_tokens_for_organization(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_clearance_phonetic_tokens_for_organization(p_organization_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  delete from public.clearance_phonetic_name_tokens where organization_id = p_organization_id;
  insert into public.clearance_phonetic_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, phonetic_primary, phonetic_alt, phonetic_codes)
  select null::integer, x.organization_id, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), dmetaphone(tok.token), dmetaphone_alt(tok.token), public.clearance_phonetic_codes(tok.token)
  from (
    select o.id as organization_id, 'organizations' as source_table, 'organization_name' as source_column, o.organization_name as source_value from public.organizations o where o.id = p_organization_id and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
    union all
    select oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name from public.organization_aliases oa join public.organizations o on o.id = oa.organization_id where oa.organization_id = p_organization_id and coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1 and cardinality(public.clearance_phonetic_codes(tok.token)) > 0;
end;
$$;


--
-- Name: upsert_clearance_phonetic_tokens_for_person(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_clearance_phonetic_tokens_for_person(p_person_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  delete from public.clearance_phonetic_name_tokens where person_id = p_person_id;
  insert into public.clearance_phonetic_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, phonetic_primary, phonetic_alt, phonetic_codes)
  select x.person_id, null::integer, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), dmetaphone(tok.token), dmetaphone_alt(tok.token), public.clearance_phonetic_codes(tok.token)
  from (
    select p.id as person_id, 'persons' as source_table, 'full_name' as source_column, p.full_name as source_value from public.persons p where p.id = p_person_id and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
    union all
    select pa.person_id, 'person_aliases', 'alias_name', pa.alias_name from public.person_aliases pa join public.persons p on p.id = pa.person_id where pa.person_id = p_person_id and coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1 and cardinality(public.clearance_phonetic_codes(tok.token)) > 0;
end;
$$;


--
-- Name: upsert_clearance_possible_tokens_for_organization(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_clearance_possible_tokens_for_organization(p_organization_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  delete from public.clearance_possible_name_tokens where organization_id = p_organization_id;
  insert into public.clearance_possible_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, first_char, first2, first3, last2, last3, ck_key, bv_key, phf_key, sz_key, skeleton)
  select null::integer, x.organization_id, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3), right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token), public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from (
    select o.id as organization_id, 'organizations' as source_table, 'organization_name' as source_column, o.organization_name as source_value from public.organizations o where o.id = p_organization_id and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
    union all
    select oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name from public.organization_aliases oa join public.organizations o on o.id = oa.organization_id where oa.organization_id = p_organization_id and coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1;
end;
$$;


--
-- Name: upsert_clearance_possible_tokens_for_person(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_clearance_possible_tokens_for_person(p_person_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  delete from public.clearance_possible_name_tokens where person_id = p_person_id;
  insert into public.clearance_possible_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, first_char, first2, first3, last2, last3, ck_key, bv_key, phf_key, sz_key, skeleton)
  select x.person_id, null::integer, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3), right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token), public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from (
    select p.id as person_id, 'persons' as source_table, 'full_name' as source_column, p.full_name as source_value from public.persons p where p.id = p_person_id and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
    union all
    select pa.person_id, 'person_aliases', 'alias_name', pa.alias_name from public.person_aliases pa join public.persons p on p.id = pa.person_id where pa.person_id = p_person_id and coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1;
end;
$$;


--
-- Name: void_case_event(bigint, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL::bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_status_code text; v_status_label text; v_status_id bigint; v_prev_status_id bigint; v_status_history_id bigint; v_old_details jsonb; v_new_details jsonb;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb; v_previous_assignment_id bigint; v_previous_assignment_old jsonb; v_previous_assignment_new jsonb; v_prev_case_status_id bigint; v_prev_stage_id bigint; v_pending_status_id bigint; v_for_raffle_stage_id bigint; v_case_raffled_stage_id bigint; v_case_reassigned_stage_id bigint; v_target_stage_id bigint; v_active_assignment_count integer; v_stage_history_id bigint;
BEGIN
  IF nullif(trim(p_void_reason), '') IS NULL THEN RAISE EXCEPTION 'Void reason is required'; END IF;
  SELECT to_jsonb(ce), ce.case_id, cet.code, ce.source_table, ce.source_id INTO v_old, v_case_id, v_event_type_code, v_source_table, v_source_id
  FROM public.case_events ce LEFT JOIN public.case_event_types cet ON cet.id = ce.event_type_id WHERE ce.id = p_case_event_id AND ce.is_voided = false;
  IF v_old IS NULL THEN RAISE EXCEPTION 'Active case event % not found', p_case_event_id; END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolution_approvals' OR v_event_type_code = 'CASE_DECISION_APPROVED' THEN
    SELECT a.id INTO v_approval_id FROM public.case_resolution_approvals a WHERE a.id = v_source_id OR a.case_event_id = p_case_event_id LIMIT 1;
    IF v_approval_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.case_court_filings cf JOIN public.case_resolution_approval_actions aa ON aa.id = cf.case_resolution_approval_action_id WHERE aa.approval_id = v_approval_id AND cf.is_voided = false) THEN
      RAISE EXCEPTION 'This approval has a court filing. Void the court filing first.';
    END IF;
  END IF;
  IF lower(coalesce(v_source_table,'')) = 'case_resolutions' OR v_event_type_code = 'CASE_RESOLVED' THEN
    SELECT cr.id INTO v_resolution_id FROM public.case_resolutions cr WHERE cr.id = v_source_id OR cr.case_event_id = p_case_event_id LIMIT 1;
    IF v_resolution_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.case_court_filings cf JOIN public.case_resolution_approval_actions aa ON aa.id = cf.case_resolution_approval_action_id JOIN public.case_resolution_approvals a ON a.id = aa.approval_id WHERE a.case_resolution_id = v_resolution_id AND cf.is_voided = false) THEN
      RAISE EXCEPTION 'This resolution has a court filing. Void the court filing first.';
    END IF;
  END IF;

  SELECT current_status_id, current_case_status_id, current_case_stage_id, to_jsonb(cpd) INTO v_prev_status_id, v_prev_case_status_id, v_prev_stage_id, v_old_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
  UPDATE public.case_events SET is_voided = true, void_reason = p_void_reason, voided_at = now(), voided_by_user_id = p_voided_by_user_id, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = p_case_event_id;
  SELECT to_jsonb(ce) INTO v_new FROM public.case_events ce WHERE ce.id = p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata) VALUES (p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id, 'Voided case timeline activity', jsonb_build_object('reason', p_void_reason));

  IF lower(coalesce(v_source_table,'')) = 'case_court_filings' OR v_event_type_code = 'COURT_FILING' THEN
    SELECT cf.id, to_jsonb(cf) INTO v_filing_id, v_filing_old FROM public.case_court_filings cf WHERE cf.id = v_source_id OR cf.case_event_id = p_case_event_id ORDER BY CASE WHEN cf.id = v_source_id THEN 0 ELSE 1 END LIMIT 1;
    IF v_filing_id IS NOT NULL THEN
      UPDATE public.case_court_filings SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_filing_id;
      SELECT to_jsonb(cf) INTO v_filing_new FROM public.case_court_filings cf WHERE cf.id = v_filing_id;
      SELECT status_code, status_label INTO v_status_code, v_status_label FROM public.recompute_case_status_after_court_filing(v_case_id) LIMIT 1;
      IF v_status_code IS NOT NULL THEN
        INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active) VALUES (v_status_code, v_status_label, CASE v_status_code WHEN 'PENDING' THEN 20 WHEN 'RESO_FOR_APPROVAL' THEN 80 WHEN 'FOR_FILING' THEN 90 WHEN 'FILED_OTHER_RESO_FOR_APPROVAL' THEN 92 WHEN 'FILED_OTHER_INFO_FOR_FILING' THEN 94 WHEN 'FILED' THEN 96 WHEN 'DISMISSED' THEN 100 ELSE 110 END, v_status_code IN ('FILED','DISMISSED','MIXED_RESULT'), v_status_code <> 'PENDING', true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,sort_order=EXCLUDED.sort_order,is_final=EXCLUDED.is_final,is_milestone=EXCLUDED.is_milestone,is_active=true RETURNING id INTO v_status_id;
        INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_case_status_id,current_case_status_date,updated_at) VALUES (v_case_id,v_status_id,CURRENT_DATE,v_status_id,CURRENT_DATE,now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,updated_at=now();
        IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (v_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_status_id,p_voided_by_user_id,now(),CURRENT_DATE,'Court filing voided. Status recomputed.',p_case_event_id) RETURNING id INTO v_status_history_id; END IF;
        SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
      END IF;
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_voided_by_user_id,'case_court_filings',v_filing_id,'VOID_COURT_FILING_FROM_EVENT',v_filing_old,jsonb_build_object('court_filing',v_filing_new,'case_private_details',v_new_details),v_case_id,'Court filing voided and case status recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'status_history_id',v_status_history_id,'reason',p_void_reason,'recomputed_status_code',v_status_code));
    END IF;
  END IF;

  IF v_event_type_code = 'CASE_ASSIGNMENT' THEN
    SELECT ca.id, to_jsonb(ca) INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_assignment_id IS NOT NULL THEN
      UPDATE public.case_assignments
      SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, unassigned_at = COALESCE(unassigned_at, now())
      WHERE id = v_assignment_id;

      SELECT to_jsonb(ca) INTO v_assignment_new
      FROM public.case_assignments ca
      WHERE ca.id = v_assignment_id;
    END IF;

    SELECT id INTO v_pending_status_id FROM public.case_statuses WHERE code = 'PENDING' AND is_active IS TRUE LIMIT 1;
    SELECT id INTO v_for_raffle_stage_id FROM public.case_stages WHERE code = 'FOR_RAFFLE' AND is_active IS TRUE LIMIT 1;
    SELECT id INTO v_case_raffled_stage_id FROM public.case_stages WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE LIMIT 1;
    IF v_pending_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status PENDING'; END IF;
    IF v_for_raffle_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage FOR_RAFFLE'; END IF;
    IF v_case_raffled_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage CASE_RAFFLED'; END IF;

    SELECT count(*) INTO v_active_assignment_count
    FROM public.case_assignments ca
    WHERE ca.case_id = v_case_id
      AND ca.unassigned_at IS NULL
      AND ca.is_voided IS FALSE;

    v_target_stage_id := CASE WHEN COALESCE(v_active_assignment_count, 0) > 0 THEN v_case_raffled_stage_id ELSE v_for_raffle_stage_id END;

    INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_case_status_id,current_case_status_date,current_case_stage_id,current_case_stage_date,updated_at)
    VALUES (v_case_id,v_pending_status_id,CURRENT_DATE,v_pending_status_id,CURRENT_DATE,v_target_stage_id,CURRENT_DATE,now())
    ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=NULL,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=NULL,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=NULL,updated_at=now();

    IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_pending_status_id THEN
      INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
      VALUES (v_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_pending_status_id,p_voided_by_user_id,now(),CURRENT_DATE,'Case Assignment voided. Broad case status remains Pending.',p_case_event_id)
      RETURNING id INTO v_status_history_id;
    END IF;

    IF v_prev_stage_id IS DISTINCT FROM v_target_stage_id THEN
      INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id)
      VALUES (v_case_id,v_prev_stage_id,v_target_stage_id,p_voided_by_user_id,now(),CURRENT_DATE,'Case Assignment voided. Workflow stage recomputed.',p_case_event_id)
      RETURNING id INTO v_stage_history_id;
    END IF;

    SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;

    INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
    VALUES (
      p_voided_by_user_id,
      'case_assignments',
      v_assignment_id,
      'VOID_CASE_ASSIGNMENT_STAGE_RECOMPUTED',
      v_assignment_old,
      jsonb_build_object('assignment', v_assignment_new, 'case_private_details', v_new_details),
      v_case_id,
      'Assignment row voided; case status kept Pending and case stage recomputed.',
      jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'case_status_id',v_pending_status_id,'case_stage_id',v_target_stage_id,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id,'active_assignment_count',v_active_assignment_count)
    );
  ELSIF v_event_type_code = 'CASE_REASSIGNMENT' THEN
    v_previous_assignment_id := NULLIF(v_old#>>'{details_jsonb,previous_assignment_id}', '')::bigint;

    SELECT ca.id, to_jsonb(ca) INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_assignment_id IS NOT NULL THEN
      UPDATE public.case_assignments
      SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, unassigned_at = COALESCE(unassigned_at, now())
      WHERE id = v_assignment_id;

      SELECT to_jsonb(ca) INTO v_assignment_new
      FROM public.case_assignments ca
      WHERE ca.id = v_assignment_id;
    END IF;

    IF v_previous_assignment_id IS NOT NULL THEN
      SELECT to_jsonb(ca) INTO v_previous_assignment_old
      FROM public.case_assignments ca
      WHERE ca.id = v_previous_assignment_id
        AND ca.case_id = v_case_id
      FOR UPDATE;

      IF v_previous_assignment_old IS NOT NULL THEN
        UPDATE public.case_assignments
        SET unassigned_at = NULL,
            unassigned_by_user_id = NULL,
            unassignment_reason = NULL
        WHERE id = v_previous_assignment_id
          AND case_id = v_case_id
          AND is_voided IS FALSE;

        SELECT to_jsonb(ca) INTO v_previous_assignment_new
        FROM public.case_assignments ca
        WHERE ca.id = v_previous_assignment_id;
      END IF;
    END IF;

    SELECT id INTO v_pending_status_id FROM public.case_statuses WHERE code = 'PENDING' AND is_active IS TRUE LIMIT 1;
    SELECT id INTO v_for_raffle_stage_id FROM public.case_stages WHERE code = 'FOR_RAFFLE' AND is_active IS TRUE LIMIT 1;
    SELECT id INTO v_case_raffled_stage_id FROM public.case_stages WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE LIMIT 1;
    IF v_pending_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status PENDING'; END IF;
    IF v_for_raffle_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage FOR_RAFFLE'; END IF;
    IF v_case_raffled_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage CASE_RAFFLED'; END IF;

    SELECT count(*) INTO v_active_assignment_count
    FROM public.case_assignments ca
    WHERE ca.case_id = v_case_id
      AND ca.unassigned_at IS NULL
      AND ca.is_voided IS FALSE;

    v_target_stage_id := CASE WHEN COALESCE(v_active_assignment_count, 0) > 0 THEN v_case_raffled_stage_id ELSE v_for_raffle_stage_id END;

    INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_case_status_id,current_case_status_date,current_case_stage_id,current_case_stage_date,updated_at)
    VALUES (v_case_id,v_pending_status_id,CURRENT_DATE,v_pending_status_id,CURRENT_DATE,v_target_stage_id,CURRENT_DATE,now())
    ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=NULL,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=NULL,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=NULL,updated_at=now();

    IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_pending_status_id THEN
      INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
      VALUES (v_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_pending_status_id,p_voided_by_user_id,now(),CURRENT_DATE,'Case Reassignment voided. Broad case status remains Pending.',p_case_event_id)
      RETURNING id INTO v_status_history_id;
    END IF;

    IF v_prev_stage_id IS DISTINCT FROM v_target_stage_id THEN
      INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id)
      VALUES (v_case_id,v_prev_stage_id,v_target_stage_id,p_voided_by_user_id,now(),CURRENT_DATE,'Case Reassignment voided. Workflow stage recomputed.',p_case_event_id)
      RETURNING id INTO v_stage_history_id;
    END IF;

    SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;

    INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
    VALUES (
      p_voided_by_user_id,
      'case_assignments',
      v_assignment_id,
      'VOID_CASE_REASSIGNMENT_NEW_ASSIGNMENT',
      v_assignment_old,
      v_assignment_new,
      v_case_id,
      'Reassignment-created assignment row voided because the Case Reassignment event was voided.',
      jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'previous_assignment_id',v_previous_assignment_id)
    );

    IF v_previous_assignment_old IS NOT NULL THEN
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_assignments',
        v_previous_assignment_id,
        'RESTORE_PREVIOUS_ASSIGNMENT_FROM_REASSIGNMENT_VOID',
        v_previous_assignment_old,
        v_previous_assignment_new,
        v_case_id,
        'Previous assignment restored because the Case Reassignment event was voided.',
        jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'voided_assignment_id',v_assignment_id)
      );
    END IF;

    INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
    VALUES (
      p_voided_by_user_id,
      'case_private_details',
      v_case_id,
      'CASE_REASSIGNMENT_VOID_STATUS_STAGE_RECOMPUTED',
      v_old_details,
      v_new_details,
      v_case_id,
      'Case Reassignment voided; case status kept Pending and case stage recomputed from active assignments.',
      jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'case_status_id',v_pending_status_id,'case_stage_id',v_target_stage_id,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id,'active_assignment_count',v_active_assignment_count,'restored_assignment_id',v_previous_assignment_id)
    );
  ELSIF lower(coalesce(v_source_table,'')) = 'case_assignments' THEN
    UPDATE public.case_assignments
    SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, unassigned_at = COALESCE(unassigned_at, now())
    WHERE id = v_source_id OR case_event_id = p_case_event_id;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolutions' OR v_event_type_code = 'CASE_RESOLVED' THEN
    SELECT cr.id INTO v_resolution_id FROM public.case_resolutions cr WHERE cr.id = v_source_id OR cr.case_event_id = p_case_event_id LIMIT 1;
    IF v_resolution_id IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id = v_resolution_id AND a.is_voided = false) THEN
        RAISE EXCEPTION 'This resolution already has approved decisions. Void the approval events first.';
      END IF;
      UPDATE public.case_resolutions SET is_voided=true, voided_at=now(), voided_by_user_id=p_voided_by_user_id, void_reason=p_void_reason, updated_by_user_id=p_voided_by_user_id, updated_at=now() WHERE id=v_resolution_id;
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolution_approvals' OR v_event_type_code = 'CASE_DECISION_APPROVED' THEN
    SELECT a.id INTO v_approval_id FROM public.case_resolution_approvals a WHERE a.id = v_source_id OR a.case_event_id = p_case_event_id LIMIT 1;
    IF v_approval_id IS NOT NULL THEN
      UPDATE public.case_resolution_approvals SET is_voided=true, voided_at=now(), voided_by_user_id=p_voided_by_user_id, void_reason=p_void_reason, updated_by_user_id=p_voided_by_user_id, updated_at=now() WHERE id=v_approval_id;
    END IF;
  END IF;

  IF v_event_type_code IN ('CASE_RESOLVED','CASE_DECISION_APPROVED') OR lower(coalesce(v_source_table,'')) IN ('case_resolutions','case_resolution_approvals') THEN
    SELECT status_code, status_label INTO v_status_code, v_status_label FROM public.recompute_case_status_after_court_filing(v_case_id) LIMIT 1;
    IF v_status_code IS NOT NULL THEN
      INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active) VALUES (v_status_code, v_status_label, CASE v_status_code WHEN 'PENDING' THEN 20 WHEN 'RESO_FOR_APPROVAL' THEN 80 WHEN 'FOR_FILING' THEN 90 WHEN 'FILED_OTHER_RESO_FOR_APPROVAL' THEN 92 WHEN 'FILED_OTHER_INFO_FOR_FILING' THEN 94 WHEN 'FILED' THEN 96 WHEN 'DISMISSED' THEN 100 ELSE 110 END, v_status_code IN ('FILED','DISMISSED','MIXED_RESULT'), v_status_code <> 'PENDING', true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,sort_order=EXCLUDED.sort_order,is_final=EXCLUDED.is_final,is_milestone=EXCLUDED.is_milestone,is_active=true RETURNING id INTO v_status_id;
      INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_case_status_id,current_case_status_date,updated_at) VALUES (v_case_id,v_status_id,CURRENT_DATE,v_status_id,CURRENT_DATE,now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,updated_at=now();
      IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (v_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_status_id,p_voided_by_user_id,now(),CURRENT_DATE,'Timeline event voided. Status recomputed.',p_case_event_id); END IF;
    END IF;
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
-- Name: check_equality_op(realtime.equality_op, regtype, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
declare
    op_symbol text;
    res boolean;
begin
    -- IS DISTINCT FROM / IS NOT DISTINCT FROM: infix, both sides typed literals
    if op = 'isdistinct' then
        execute format(
            'select %L::%s %s %L::%s',
            val_1,
            type_::text,
            case when negate then 'IS NOT DISTINCT FROM' else 'IS DISTINCT FROM' end,
            val_2,
            type_::text
        ) into res;
        return res;
    end if;

    -- IS requires a keyword RHS (NULL, TRUE, FALSE, UNKNOWN), not a typed literal
    if op = 'is' then
        if val_2 not in ('null', 'true', 'false', 'unknown') then
            raise exception 'invalid value for is filter: must be null, true, false, or unknown';
        end if;
        execute format(
            'select %L::%s %s %s',
            val_1,
            type_::text,
            case when negate then 'IS NOT' else 'IS' end,
            upper(val_2)
        ) into res;
        return res;
    end if;

    op_symbol = case
        when op = 'eq'    then '='
        when op = 'neq'   then '!='
        when op = 'lt'    then '<'
        when op = 'lte'   then '<='
        when op = 'gt'    then '>'
        when op = 'gte'   then '>='
        when op = 'in'    then '= any'
        when op = 'like'   then 'LIKE'
        when op = 'ilike'  then 'ILIKE'
        when op = 'match'  then '~'
        when op = 'imatch' then '~*'
        else null
    end;

    if op_symbol is null then
        raise exception 'unsupported equality operator: %', op::text;
    end if;

    execute format(
        'select %L::%s %s (%L::%s)',
        val_1,
        type_::text,
        op_symbol,
        val_2,
        case when op = 'in' then type_::text || '[]' else type_::text end
    ) into res;

    return case when negate then not res else res end;
end;
$$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    select
        filters is null
        or array_length(filters, 1) is null
        or coalesce(
            count(col.name) = count(1)
            and sum(
                realtime.check_equality_op(
                    op:=f.op,
                    type_:=coalesce(col.type_oid::regtype, col.type_name::regtype),
                    val_1:=col.value #>> '{}',
                    val_2:=f.value,
                    negate:=coalesce(f.negate, false)
                )::int
            ) filter (where col.name is not null) = count(col.name),
            false
        )
    from
        unnest(filters) f
        left join unnest(columns) col
            on f.column_name = col.name;
$$;


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
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
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
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
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
            array_agg(a.attname order by a.attnum),
            '{}'::text[]
        )
        from
            pg_catalog.pg_attribute a
        where
            a.attrelid = new.entity
            and a.attnum > 0
            and not a.attisdropped
            and pg_catalog.has_column_privilege(
                (new.claims ->> 'role'),
                a.attrelid,
                a.attnum,
                'SELECT'
            );
    filter realtime.user_defined_filter;
    col_type regtype;
    in_val jsonb;
    selected_col text;
begin
    for filter in select * from unnest(new.filters) loop
        if not filter.column_name = any(col_names) then
            raise exception 'invalid column for filter %', filter.column_name;
        end if;

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
        elsif filter.op = 'is'::realtime.equality_op then
            -- `is` requires a keyword RHS rather than a typed literal
            if filter.value not in ('null', 'true', 'false', 'unknown') then
                raise exception 'invalid value for is filter: must be null, true, false, or unknown';
            end if;
            -- IS NULL works for any type, but IS TRUE/FALSE/UNKNOWN require a boolean
            -- operand. Reject the non-null keywords on non-boolean columns here so they
            -- don't abort apply_rls at WAL time.
            if filter.value <> 'null' and col_type <> 'boolean'::regtype then
                raise exception 'is % filter requires a boolean column, got %', filter.value, col_type::text;
            end if;
        elsif filter.op in ('like'::realtime.equality_op, 'ilike'::realtime.equality_op) then
            -- like/ilike apply the text pattern operator (~~); reject column types that
            -- have no such operator instead of failing at WAL time
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = '~~' and oprleft = col_type
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
        elsif filter.op in ('match'::realtime.equality_op, 'imatch'::realtime.equality_op) then
            -- match/imatch apply the regex operators ~ / ~*; reject column types that have
            -- no such operator (e.g. integer) instead of failing at WAL time, mirroring the
            -- like/ilike guard above.
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = case when filter.op = 'imatch'::realtime.equality_op then '~*' else '~' end
                  and oprleft = col_type
                  and oprright = col_type
                  and oprresult = 'boolean'::regtype
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
            -- validate the regex eagerly so a bad pattern is rejected here, not inside
            -- apply_rls where it would abort the WAL stream for the entity
            begin
                perform '' ~ filter.value;
            exception when others then
                raise exception 'invalid regular expression for % filter: %', filter.op::text, sqlerrm;
            end;
        else
            -- eq/neq/lt/lte/gt/gte: value must be coercable to the type
            perform realtime.cast(filter.value, col_type);
        end if;
    end loop;

    if new.selected_columns is not null then
        for selected_col in select * from unnest(new.selected_columns) loop
            if not selected_col = any(col_names) then
                raise exception 'invalid column for select %', selected_col;
            end if;
        end loop;
    end if;

    -- Apply consistent order to filters so the unique constraint can't be tricked by a
    -- different filter order. negate is part of the sort key.
    new.filters = coalesce(
        array_agg(f order by f.column_name, f.op, f.value, f.negate),
        '{}'
    ) from unnest(new.filters) f;

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
    custom_claims_allowlist text[] DEFAULT '{}'::text[] NOT NULL,
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
-- Name: _rls_policy_backup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public._rls_policy_backup (
    id bigint NOT NULL,
    backup_label text NOT NULL,
    backed_up_at timestamp with time zone DEFAULT now() NOT NULL,
    schemaname text NOT NULL,
    tablename text NOT NULL,
    policyname text NOT NULL,
    permissive text,
    roles text[],
    command text,
    using_expression text,
    check_expression text
);


--
-- Name: _rls_policy_backup_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public._rls_policy_backup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _rls_policy_backup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public._rls_policy_backup_id_seq OWNED BY public._rls_policy_backup.id;


--
-- Name: _rls_table_state_backup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public._rls_table_state_backup (
    id bigint NOT NULL,
    backup_label text NOT NULL,
    backed_up_at timestamp with time zone DEFAULT now() NOT NULL,
    schemaname text NOT NULL,
    tablename text NOT NULL,
    rls_enabled boolean NOT NULL,
    rls_forced boolean NOT NULL
);


--
-- Name: _rls_table_state_backup_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public._rls_table_state_backup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _rls_table_state_backup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public._rls_table_state_backup_id_seq OWNED BY public._rls_table_state_backup.id;


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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    case_id bigint,
    summary text,
    metadata jsonb
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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by_user_id bigint,
    delete_reason text
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
    case_event_id bigint,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by_user_id bigint,
    void_reason text,
    unassigned_by_user_id bigint,
    unassignment_reason text
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
-- Name: case_court_filings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_court_filings (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    case_event_id bigint,
    case_resolution_approval_id bigint NOT NULL,
    case_resolution_approval_action_id bigint NOT NULL,
    court_id bigint,
    court_name text NOT NULL,
    court_branch text,
    charge_filed text NOT NULL,
    date_filed date NOT NULL,
    time_filed time without time zone,
    information_count integer,
    criminal_case_no text,
    court_status text,
    remarks text,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by_user_id bigint,
    void_reason text
);


--
-- Name: case_court_filings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_court_filings ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_court_filings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


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
    case_status_id bigint,
    case_stage_id bigint,
    CONSTRAINT chk_case_events_void_reason CHECK ((((is_voided = false) AND (voided_at IS NULL)) OR (is_voided = true)))
);


--
-- Name: TABLE case_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_events IS 'Central MVP timeline/activity table for cases. UI should CRUD case_events through functions/API; specialized tables can be updated by the backend/function when needed.';


--
-- Name: COLUMN case_events.case_status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_events.case_status_id IS 'Broad legal outcome status associated with this timeline event. Legacy status_id remains for compatibility.';


--
-- Name: COLUMN case_events.case_stage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_events.case_stage_id IS 'Automatic workflow stage associated with this timeline event. Legacy status_id remains for compatibility.';


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
-- Name: case_participant_corrections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_participant_corrections (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    case_participant_id bigint NOT NULL,
    old_person_id bigint,
    new_person_id bigint,
    old_snapshot_json jsonb NOT NULL,
    new_snapshot_json jsonb NOT NULL,
    reason text,
    corrected_by_user_id bigint,
    corrected_at timestamp with time zone DEFAULT now() NOT NULL,
    old_organization_id bigint,
    new_organization_id bigint
);


--
-- Name: case_participant_corrections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_participant_corrections ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_participant_corrections_id_seq
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    current_case_status_id bigint,
    current_case_status_date date,
    current_case_status_remarks text,
    current_case_stage_id bigint,
    current_case_stage_date date,
    current_case_stage_remarks text
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
-- Name: COLUMN case_private_details.current_case_status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.current_case_status_id IS 'Broad legal outcome status. During phased refactor, legacy current_status_id remains for compatibility.';


--
-- Name: COLUMN case_private_details.current_case_stage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.case_private_details.current_case_stage_id IS 'Automatic workflow stage. During phased refactor, legacy current_status_id remains for compatibility.';


--
-- Name: case_resolution_approval_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_resolution_approval_actions (
    id bigint NOT NULL,
    approval_id bigint NOT NULL,
    case_id bigint NOT NULL,
    source_resolution_charge_action_id bigint,
    case_violation_id bigint,
    violation_id bigint,
    charge_text text NOT NULL,
    decision_code text NOT NULL,
    display_order integer NOT NULL,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT case_resolution_approval_actions_decision_code_check CHECK ((decision_code = ANY (ARRAY['FOR_FILING'::text, 'DISMISSAL'::text])))
);


--
-- Name: case_resolution_approval_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_resolution_approval_actions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_resolution_approval_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_resolution_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_resolution_approvals (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    case_event_id bigint NOT NULL,
    case_resolution_id bigint,
    approved_by_prosecutor_id bigint NOT NULL,
    date_approved date NOT NULL,
    time_approved time without time zone,
    final_status_code text NOT NULL,
    remarks text,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by_user_id bigint,
    void_reason text,
    CONSTRAINT case_resolution_approvals_final_status_code_check CHECK ((final_status_code = ANY (ARRAY['FOR_FILING'::text, 'DISMISSED'::text, 'MIXED_RESULT'::text])))
);


--
-- Name: case_resolution_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_resolution_approvals ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_resolution_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_resolution_charge_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_resolution_charge_actions (
    id bigint NOT NULL,
    case_resolution_id bigint NOT NULL,
    case_id bigint NOT NULL,
    case_violation_id bigint,
    violation_id bigint,
    charge_text text NOT NULL,
    action_code text NOT NULL,
    display_order integer DEFAULT 0,
    remarks text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT case_resolution_charge_actions_action_code_check CHECK ((action_code = ANY (ARRAY['FOR_FILING'::text, 'DISMISSAL'::text])))
);


--
-- Name: case_resolution_charge_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_resolution_charge_actions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_resolution_charge_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_resolutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_resolutions (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    case_event_id bigint,
    recommendation_code text NOT NULL,
    date_resolved date NOT NULL,
    time_resolved time without time zone,
    remarks text,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by_user_id bigint,
    void_reason text,
    CONSTRAINT case_resolutions_recommendation_code_check CHECK ((recommendation_code = ANY (ARRAY['CASE_FOR_FILING'::text, 'CASE_DISMISSAL'::text, 'MIXED_RESULT'::text])))
);


--
-- Name: case_resolutions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.case_resolutions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.case_resolutions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: case_stage_colors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_stage_colors (
    id bigint NOT NULL,
    stage_id bigint NOT NULL,
    color_name text,
    background_class text,
    text_class text,
    border_class text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_stage_colors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_stage_colors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_stage_colors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_stage_colors_id_seq OWNED BY public.case_stage_colors.id;


--
-- Name: case_stage_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_stage_history (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    from_stage_id bigint,
    to_stage_id bigint,
    changed_by_user_id bigint,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    stage_date date,
    remarks text,
    case_event_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE case_stage_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_stage_history IS 'Workflow stage transition history backfilled from legacy case_status_history during phased Case Status / Case Stage split.';


--
-- Name: case_stage_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_stage_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_stage_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_stage_history_id_seq OWNED BY public.case_stage_history.id;


--
-- Name: case_stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_stages (
    id bigint NOT NULL,
    code text NOT NULL,
    display_label character varying(100) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_final_stage boolean DEFAULT false NOT NULL,
    is_milestone boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE case_stages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.case_stages IS 'Reference table for automatic workflow stages split out from broad case statuses.';


--
-- Name: case_stages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_stages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_stages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_stages_id_seq OWNED BY public.case_stages.id;


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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by_user_id bigint,
    delete_reason text
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
    person_id integer,
    source_table text NOT NULL,
    source_column text NOT NULL,
    source_value text NOT NULL,
    token text NOT NULL,
    token_order integer NOT NULL,
    token_len integer NOT NULL,
    phonetic_primary text,
    phonetic_alt text,
    phonetic_codes text[] NOT NULL,
    refreshed_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id integer
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
    person_id integer,
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
    refreshed_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id integer
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
-- Name: contact_informations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact_informations (
    id bigint NOT NULL,
    contact_type text NOT NULL,
    contact_value text NOT NULL,
    label text,
    is_primary boolean DEFAULT false NOT NULL,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contact_informations_contact_type_check CHECK ((contact_type = ANY (ARRAY['PHONE'::text, 'EMAIL'::text, 'OTHER'::text]))),
    CONSTRAINT contact_informations_value_not_blank CHECK ((btrim(contact_value) <> ''::text))
);


--
-- Name: contact_informations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.contact_informations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contact_informations_id_seq
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by_user_id bigint,
    delete_reason text
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
-- Name: organization_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_addresses (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    address_id bigint NOT NULL,
    address_type_id bigint NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    start_date date,
    end_date date,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    deactivated_at timestamp with time zone,
    deactivated_by_user_id bigint,
    deactivation_reason text
);


--
-- Name: organization_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.organization_addresses ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.organization_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


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
    details_jsonb jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by_user_id bigint,
    void_reason text,
    replaced_by_organization_id bigint
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
-- Name: participant_contact_informations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.participant_contact_informations (
    id bigint NOT NULL,
    case_participant_id bigint NOT NULL,
    contact_information_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    deactivated_at timestamp with time zone,
    deactivated_by_user_id bigint,
    deactivation_reason text
);


--
-- Name: participant_contact_informations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.participant_contact_informations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.participant_contact_informations_id_seq
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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    deactivated_at timestamp with time zone,
    deactivated_by_user_id bigint,
    deactivation_reason text
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
    is_pwd boolean,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by_user_id bigint,
    void_reason text,
    replaced_by_person_id bigint
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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    position_code text,
    CONSTRAINT prosecutors_position_code_check CHECK (((position_code IS NULL) OR (position_code = ANY (ARRAY['CHIEF_PROSECUTOR'::text, 'DEPUTY_PROSECUTOR'::text, 'PROSECUTOR'::text]))))
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
-- Name: v_address_suggestions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_address_suggestions AS
 SELECT id,
    line1,
    line2,
    barangay,
    city,
    province,
    region,
    zip_code,
    country,
    latitude,
    longitude,
    created_at
   FROM public.addresses;


--
-- Name: VIEW v_address_suggestions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_address_suggestions IS 'Frontend address suggestion view; security policies will be implemented later.';


--
-- Name: v_case_assignment_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_assignment_detail AS
 SELECT ca.id,
    ca.case_id,
    ca.prosecutor_id,
    ca.staff_id,
    ca.prosecutor_staff_assignment_id,
    ca.assigned_by_user_id,
    ca.assigned_at,
    ca.unassigned_at,
    ca.remarks,
    ca.legacy_date_raffled_raw,
    ca.case_event_id,
        CASE
            WHEN (p.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('full_name', p.full_name, 'short_name', p.short_name)
        END AS prosecutors,
        CASE
            WHEN (s.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('full_name', s.full_name, 'short_name', s.short_name)
        END AS staff
   FROM ((public.case_assignments ca
     LEFT JOIN public.prosecutors p ON ((p.id = ca.prosecutor_id)))
     LEFT JOIN public.staff s ON ((s.id = ca.staff_id)));


--
-- Name: VIEW v_case_assignment_detail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_assignment_detail IS 'Frontend case-assignment read view; security policies will be implemented later.';


--
-- Name: v_case_attachments; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_attachments AS
 SELECT id,
    case_id,
    gdrive_file_id,
    gdrive_parent_folder_id,
    file_name,
    mime_type,
    web_view_link,
    web_content_link,
    file_size_bytes,
    md5_checksum,
    modified_time,
    local_cache_path,
    is_available_offline,
    first_seen_at,
    last_seen_at,
    last_scanned_at,
    indexed_by_user_id,
    file_status,
    created_at,
    updated_at
   FROM public.case_attachment_index;


--
-- Name: VIEW v_case_attachments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_attachments IS 'Case details attachment read view. Intentionally policy-free for development debugging.';


--
-- Name: v_case_courts_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_courts_detail AS
 SELECT cc.id,
    cc.case_id,
    cc.court_id,
    cc.court_order,
    cc.raw_court_text,
    cc.court_branch,
    cc.charge_filed,
    cc.criminal_case_number,
    cc.information_count,
    cc.date_filed_in_court,
    cc.actual_filing_date,
    cc.court_status,
    cc.court_remarks,
    cc.needs_review,
    cc.review_reason,
    cc.source,
    cc.legacy_source_file,
    cc.legacy_source_sheet,
    cc.legacy_row_number,
    cc.created_at,
    cc.updated_at,
    cc.date_filed_in_court_raw,
    cc.case_event_id,
    cc.information_count_raw,
    jsonb_build_object('code', co.code, 'court_type', co.court_type, 'name', co.name) AS courts
   FROM (public.case_courts cc
     LEFT JOIN public.courts co ON ((co.id = cc.court_id)));


--
-- Name: VIEW v_case_courts_detail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_courts_detail IS 'Case details court read view. Intentionally policy-free for development debugging.';


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
-- Name: v_case_details_page; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_details_page AS
 WITH latest_assignment AS (
         SELECT DISTINCT ON (ca.case_id) ca.case_id,
            ca.prosecutor_id,
            ca.staff_id,
            ca.assigned_at,
            ca.id
           FROM public.case_assignments ca
          WHERE ((ca.unassigned_at IS NULL) AND (COALESCE(ca.is_voided, false) IS FALSE))
          ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
        ), violation_summary AS (
         SELECT cv.case_id,
            string_agg(COALESCE(NULLIF(btrim(cv.raw_violation_text), ''::text), v.title), ', '::text ORDER BY cv.violation_order, cv.id) AS violations
           FROM (public.case_violations cv
             LEFT JOIN public.violations v ON ((v.id = cv.violation_id)))
          WHERE (COALESCE(cv.is_deleted, false) IS FALSE)
          GROUP BY cv.case_id
        ), note_summary AS (
         SELECT n.case_id,
            jsonb_agg(jsonb_build_object('id', n.id, 'note_text', n.note_text, 'is_private', n.is_private, 'created_by_user_id', n.created_by_user_id, 'created_at', n.created_at, 'updated_at', n.updated_at) ORDER BY n.created_at DESC, n.id DESC) AS notes
           FROM public.notes n
          WHERE (COALESCE(n.is_deleted, false) IS FALSE)
          GROUP BY n.case_id
        ), case_address_summary AS (
         SELECT ca.case_id,
            jsonb_agg(jsonb_build_object('id', ca.id, 'address_id', ca.address_id, 'address_type_id', ca.address_type_id, 'address_type_label', at.display_label, 'is_primary', ca.is_primary, 'remarks', ca.remarks, 'addresses', jsonb_build_object('barangay', a.barangay, 'city', a.city, 'country', a.country, 'line1', a.line1, 'line2', a.line2, 'province', a.province, 'region', a.region, 'zip_code', a.zip_code)) ORDER BY ca.is_primary DESC, ca.id) AS case_addresses
           FROM ((public.case_addresses ca
             JOIN public.addresses a ON ((a.id = ca.address_id)))
             LEFT JOIN public.address_types at ON ((at.id = ca.address_type_id)))
          WHERE (COALESCE(ca.is_deleted, false) IS FALSE)
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
    concat_ws('-'::text, c.region_code, dt.prefix, ("right"((c.docket_year)::text, 2) || COALESCE(c.docket_month_code, ''::text)), lpad((c.docket_number)::text, 6, '0'::text)) AS docket_display_number,
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


--
-- Name: VIEW v_case_details_page; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_details_page IS 'Case details page read model with legacy status plus split case status and case stage fields. Intentionally policy-free for development debugging.';


--
-- Name: v_case_motions_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_motions_detail AS
 SELECT id,
    case_id,
    motion_order,
    motion_name,
    filed_by,
    filed_by_raw,
    date_received,
    date_received_raw,
    date_resolved,
    date_resolved_raw,
    date_approved,
    date_approved_raw,
    motion_status,
    motion_status_raw,
    remarks,
    remarks_raw,
    created_at,
    updated_at
   FROM public.case_motions;


--
-- Name: VIEW v_case_motions_detail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_motions_detail IS 'Case details motion read view. Intentionally policy-free for development debugging.';


--
-- Name: v_case_participant_corrections; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_participant_corrections AS
 SELECT c.id,
    c.case_id,
    c.case_participant_id,
    c.old_person_id,
    c.new_person_id,
    c.old_organization_id,
    c.new_organization_id,
    c.old_snapshot_json,
    c.new_snapshot_json,
    c.reason,
    c.corrected_by_user_id,
    COALESCE(s.full_name, p.full_name, (u.email)::text, ('User #'::text || (c.corrected_by_user_id)::text)) AS corrected_by_display,
    c.corrected_at
   FROM (((public.case_participant_corrections c
     LEFT JOIN public.users u ON ((u.id = c.corrected_by_user_id)))
     LEFT JOIN public.staff s ON ((s.id = u.staff_id)))
     LEFT JOIN public.prosecutors p ON ((p.id = u.prosecutor_id)));


--
-- Name: v_case_participants_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_participants_detail AS
 SELECT cp.id,
    cp.case_id,
    cp.person_id,
    cp.role_id,
    cp.created_at,
    cp.participant_order,
    cp.organization_id,
    cp.participant_kind,
    cp.display_name_snapshot,
    cppd.remarks,
    cppd.source,
    cppd.source_detail,
    cppd.legacy_source_file,
    cppd.legacy_source_sheet,
    cppd.legacy_row_number,
    cppd.legacy_raw_text,
    jsonb_build_object('code', pr.code, 'display_label', pr.display_label) AS participant_roles,
    COALESCE(pci.contact_informations, '[]'::jsonb) AS contact_informations,
        CASE
            WHEN (cpa.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('age_text', cpa.age_text, 'age_years', cpa.age_years, 'gender_text', cpa.gender_text, 'gender_normalized', cpa.gender_normalized, 'is_minor_at_case', cpa.is_minor_at_case, 'is_senior_at_case', cpa.is_senior_at_case, 'is_pwd_at_case', cpa.is_pwd_at_case)
        END AS case_participant_attributes,
        CASE
            WHEN (p.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('age', p.age, 'birth_date', p.birth_date, 'first_name', p.first_name, 'full_name', p.full_name, 'gender', p.gender, 'id', p.id, 'is_minor', p.is_minor, 'is_pwd', p.is_pwd, 'is_senior', p.is_senior, 'last_name', p.last_name, 'middle_name', p.middle_name, 'notes', p.notes, 'person_descriptor', p.person_descriptor, 'suffix', p.suffix, 'is_voided', COALESCE(p.is_voided, false), 'replaced_by_person_id', p.replaced_by_person_id, 'person_aliases', COALESCE(pal.person_aliases, '[]'::jsonb), 'person_addresses', COALESCE(pa.person_addresses, '[]'::jsonb))
        END AS persons,
        CASE
            WHEN (o.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('id', o.id, 'organization_name', o.organization_name, 'contact_person', o.contact_person, 'contact_number', o.contact_number, 'email', o.email, 'details_jsonb', o.details_jsonb, 'is_voided', COALESCE(o.is_voided, false), 'replaced_by_organization_id', o.replaced_by_organization_id, 'organization_aliases', COALESCE(oa.organization_aliases, '[]'::jsonb), 'organization_addresses', COALESCE(org_addr.organization_addresses, '[]'::jsonb))
        END AS organizations
   FROM ((((((((((public.case_participants cp
     LEFT JOIN public.case_participant_private_details cppd ON ((cppd.case_participant_id = cp.id)))
     LEFT JOIN public.case_participant_attributes cpa ON ((cpa.case_participant_id = cp.id)))
     LEFT JOIN public.participant_roles pr ON ((pr.id = cp.role_id)))
     LEFT JOIN public.persons p ON ((p.id = cp.person_id)))
     LEFT JOIN public.organizations o ON ((o.id = cp.organization_id)))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', ci.id, 'participant_contact_information_id', pci_1.id, 'contact_type', ci.contact_type, 'contact_value', ci.contact_value, 'label', ci.label, 'is_primary', ci.is_primary, 'remarks', ci.remarks) ORDER BY ci.is_primary DESC NULLS LAST, ci.contact_type, ci.id) AS contact_informations
           FROM (public.participant_contact_informations pci_1
             JOIN public.contact_informations ci ON ((ci.id = pci_1.contact_information_id)))
          WHERE ((pci_1.case_participant_id = cp.id) AND (COALESCE(pci_1.is_active, true) IS TRUE))) pci ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', a.id, 'alias_name', a.alias_name, 'is_active', a.is_active) ORDER BY a.is_active DESC NULLS LAST, a.alias_name) AS person_aliases
           FROM public.person_aliases a
          WHERE ((a.person_id = p.id) AND (a.is_active IS TRUE))) pal ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', paddr.id, 'address_id', paddr.address_id, 'address_type_id', paddr.address_type_id, 'is_primary', paddr.is_primary, 'remarks', paddr.remarks, 'addresses',
                CASE
                    WHEN (a.id IS NULL) THEN NULL::jsonb
                    ELSE jsonb_build_object('id', a.id, 'barangay', a.barangay, 'city', a.city, 'country', a.country, 'line1', a.line1, 'line2', a.line2, 'province', a.province, 'region', a.region, 'zip_code', a.zip_code)
                END) ORDER BY paddr.is_primary DESC NULLS LAST, paddr.id) AS person_addresses
           FROM (public.person_addresses paddr
             LEFT JOIN public.addresses a ON ((a.id = paddr.address_id)))
          WHERE ((paddr.person_id = p.id) AND (COALESCE(paddr.is_active, true) IS TRUE) AND ((paddr.end_date IS NULL) OR (paddr.end_date > CURRENT_DATE)))) pa ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', a.id, 'alias_name', a.alias_name, 'is_active', a.is_active) ORDER BY a.is_active DESC NULLS LAST, a.alias_name) AS organization_aliases
           FROM public.organization_aliases a
          WHERE ((a.organization_id = o.id) AND (a.is_active IS TRUE))) oa ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', oaddr.id, 'address_id', oaddr.address_id, 'address_type_id', oaddr.address_type_id, 'is_primary', oaddr.is_primary, 'remarks', oaddr.remarks, 'addresses',
                CASE
                    WHEN (a.id IS NULL) THEN NULL::jsonb
                    ELSE jsonb_build_object('id', a.id, 'barangay', a.barangay, 'city', a.city, 'country', a.country, 'line1', a.line1, 'line2', a.line2, 'province', a.province, 'region', a.region, 'zip_code', a.zip_code)
                END) ORDER BY oaddr.is_primary DESC NULLS LAST, oaddr.id) AS organization_addresses
           FROM (public.organization_addresses oaddr
             LEFT JOIN public.addresses a ON ((a.id = oaddr.address_id)))
          WHERE ((oaddr.organization_id = o.id) AND (COALESCE(oaddr.is_active, true) IS TRUE) AND ((oaddr.end_date IS NULL) OR (oaddr.end_date > CURRENT_DATE)))) org_addr ON (true));


--
-- Name: v_case_participant_details; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_participant_details AS
 SELECT id,
    case_id,
    person_id,
    role_id,
    created_at,
    participant_order,
    organization_id,
    participant_kind,
    display_name_snapshot,
    remarks,
    source,
    source_detail,
    legacy_source_file,
    legacy_source_sheet,
    legacy_row_number,
    legacy_raw_text,
    participant_roles,
    contact_informations,
    case_participant_attributes,
    persons,
    organizations
   FROM public.v_case_participants_detail;


--
-- Name: v_case_petitions_for_review_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_petitions_for_review_detail AS
 SELECT id,
    case_id,
    petition_title,
    handling_prosecutor_text,
    date_received,
    date_received_raw,
    filed_by,
    petition_status,
    date_resolved,
    date_resolved_raw,
    date_approved,
    date_approved_raw,
    remarks
   FROM public.case_petitions_for_review;


--
-- Name: VIEW v_case_petitions_for_review_detail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_petitions_for_review_detail IS 'Case details petition-for-review read view. Intentionally policy-free for development debugging.';


--
-- Name: v_case_stage_history_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_stage_history_detail AS
 SELECT csh.id,
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
   FROM ((public.case_stage_history csh
     LEFT JOIN public.case_stages fs ON ((fs.id = csh.from_stage_id)))
     LEFT JOIN public.case_stages ts ON ((ts.id = csh.to_stage_id)));


--
-- Name: VIEW v_case_stage_history_detail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_stage_history_detail IS 'Frontend case-stage-history read view for phased Case Status / Case Stage split.';


--
-- Name: v_case_status_history_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_status_history_detail AS
 SELECT csh.id,
    csh.case_id,
    csh.from_status_id,
    csh.to_status_id,
    csh.changed_by_user_id,
    csh.changed_at,
    csh.remarks,
    csh.status_date,
    csh.legacy_status_approved_date_raw,
    csh.legacy_status_date_raw,
    csh.case_event_id,
        CASE
            WHEN (fs.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('code', fs.code, 'display_label', fs.display_label)
        END AS from_status,
        CASE
            WHEN (ts.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('code', ts.code, 'display_label', ts.display_label)
        END AS to_status
   FROM ((public.case_status_history csh
     LEFT JOIN public.case_statuses fs ON ((fs.id = csh.from_status_id)))
     LEFT JOIN public.case_statuses ts ON ((ts.id = csh.to_status_id)));


--
-- Name: VIEW v_case_status_history_detail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_status_history_detail IS 'Frontend case-status-history read view; security policies will be implemented later.';


--
-- Name: v_case_timeline; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_case_timeline AS
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
   FROM ((((((((((public.case_events ce
     JOIN public.cases c ON ((c.id = ce.case_id)))
     JOIN public.docket_types dt ON ((dt.id = c.docket_type_id)))
     JOIN public.case_event_types cet ON ((cet.id = ce.event_type_id)))
     LEFT JOIN public.case_statuses cs ON ((cs.id = ce.status_id)))
     LEFT JOIN public.case_statuses event_status ON ((event_status.id = ce.case_status_id)))
     LEFT JOIN public.case_stages event_stage ON ((event_stage.id = ce.case_stage_id)))
     LEFT JOIN public.prosecutors p ON ((p.id = ce.prosecutor_id)))
     LEFT JOIN public.staff st ON ((st.id = ce.staff_id)))
     LEFT JOIN public.courts co ON ((co.id = ce.court_id)))
     LEFT JOIN public.users vu ON ((vu.id = ce.voided_by_user_id)));


--
-- Name: VIEW v_case_timeline; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_timeline IS 'Case details page timeline read model with legacy event status plus split case status and case stage fields.';


--
-- Name: v_clearance_participant_attributes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_clearance_participant_attributes AS
 SELECT cp.case_id,
    cp.person_id,
    cpa.age_text,
    cpa.age_years
   FROM (public.case_participants cp
     LEFT JOIN public.case_participant_attributes cpa ON ((cpa.case_participant_id = cp.id)));


--
-- Name: VIEW v_clearance_participant_attributes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_clearance_participant_attributes IS 'Clearance search participant age attribute read view. Intentionally policy-free for development debugging.';


--
-- Name: v_docket_case_violation_classification; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_docket_case_violation_classification AS
 WITH violation_summary AS (
         SELECT cv.case_id,
            string_agg(COALESCE(NULLIF(btrim(cv.raw_violation_text), ''::text), v.title), ', '::text ORDER BY cv.violation_order, cv.id) AS violations
           FROM (public.case_violations cv
             LEFT JOIN public.violations v ON ((v.id = cv.violation_id)))
          GROUP BY cv.case_id
        )
 SELECT c.id,
    vs.violations,
    cpd.summary_text,
    cc.display_label AS case_classification_label
   FROM (((public.cases c
     LEFT JOIN public.case_private_details cpd ON ((cpd.case_id = c.id)))
     LEFT JOIN public.case_classifications cc ON ((cc.id = c.case_classification_id)))
     LEFT JOIN violation_summary vs ON ((vs.case_id = c.id)))
  WHERE (NOT c.is_archived);


--
-- Name: VIEW v_docket_case_violation_classification; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_docket_case_violation_classification IS 'Cases page violation and classification hydration view. Intentionally policy-free for development debugging.';


--
-- Name: v_docket_shell; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_docket_shell AS
 SELECT c.id,
    c.docket_type_id,
    c.docket_year,
    c.docket_number,
    c.docket_month_code,
    concat_ws('-'::text, dt.prefix, (c.docket_year)::text, NULLIF(c.docket_month_code, ''::text), lpad((c.docket_number)::text, 6, '0'::text)) AS docket_display_number,
    dt.prefix AS docket_type_prefix,
    dt.name AS docket_type_name,
    c.created_at
   FROM (public.cases c
     JOIN public.docket_types dt ON ((dt.id = c.docket_type_id)))
  WHERE (NOT c.is_archived);


--
-- Name: v_docket_case_labels; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_docket_case_labels AS
 SELECT s.id,
    s.docket_display_number,
    COALESCE(l.violations, l.summary_text) AS label,
    l.violations,
    l.case_classification_label
   FROM (public.v_docket_shell s
     LEFT JOIN public.v_docket_case_violation_classification l ON ((l.id = s.id)));


--
-- Name: VIEW v_docket_case_labels; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_docket_case_labels IS 'Docket label helper view backed by split shell and label views. Intentionally policy-free for development debugging.';


--
-- Name: v_docket_participants; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_docket_participants AS
 WITH participant_names AS (
         SELECT cp.case_id,
            lower(concat_ws(' '::text, pr.code, pr.display_label)) AS role_text,
            cp.participant_order,
            cp.id AS case_participant_id,
            COALESCE(NULLIF(btrim(p.full_name), ''::text), NULLIF(btrim(o.organization_name), ''::text), NULLIF(btrim(cp.display_name_snapshot), ''::text)) AS display_name
           FROM (((public.case_participants cp
             JOIN public.participant_roles pr ON ((pr.id = cp.role_id)))
             LEFT JOIN public.persons p ON ((p.id = cp.person_id)))
             LEFT JOIN public.organizations o ON ((o.id = cp.organization_id)))
        )
 SELECT case_id AS id,
    string_agg(display_name, ' | '::text ORDER BY participant_order, case_participant_id) FILTER (WHERE ((role_text ~~ '%complainant%'::text) AND (display_name IS NOT NULL))) AS complainant,
    string_agg(display_name, ' | '::text ORDER BY participant_order, case_participant_id) FILTER (WHERE ((role_text ~~ '%respondent%'::text) AND (display_name IS NOT NULL))) AS respondent
   FROM participant_names pn
  GROUP BY case_id;


--
-- Name: VIEW v_docket_participants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_docket_participants IS 'Cases page participant names read model. Intentionally policy-free for development debugging.';


--
-- Name: v_docket_quickdetails; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_docket_quickdetails AS
 WITH latest_assignment AS (
         SELECT DISTINCT ON (ca.case_id) ca.case_id,
            ca.prosecutor_id,
            ca.assigned_at,
            ca.id
           FROM public.case_assignments ca
          WHERE ((ca.unassigned_at IS NULL) AND (ca.is_voided IS FALSE))
          ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
        )
 SELECT c.id,
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
   FROM ((((((public.cases c
     LEFT JOIN public.case_private_details cpd ON ((cpd.case_id = c.id)))
     LEFT JOIN public.case_statuses cs ON ((cs.id = cpd.current_status_id)))
     LEFT JOIN public.case_statuses broad_status ON ((broad_status.id = cpd.current_case_status_id)))
     LEFT JOIN public.case_stages stage ON ((stage.id = cpd.current_case_stage_id)))
     LEFT JOIN latest_assignment la ON ((la.case_id = c.id)))
     LEFT JOIN public.prosecutors p ON ((p.id = la.prosecutor_id)))
  WHERE (NOT c.is_archived);


--
-- Name: VIEW v_docket_quickdetails; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_docket_quickdetails IS 'Cases page quick details read model for prosecutor, legacy status, split case status, split case stage, and received date. Intentionally policy-free for development debugging.';


--
-- Name: v_docket_sequence_lookup; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_docket_sequence_lookup AS
 SELECT id,
    docket_type_id,
    docket_year,
    next_number,
    last_issued_number,
    created_at,
    updated_at
   FROM public.docket_sequence_counters;


--
-- Name: VIEW v_docket_sequence_lookup; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_docket_sequence_lookup IS 'Frontend docket-number preview view; security policies will be implemented later.';


--
-- Name: v_organization_details; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_organization_details AS
 SELECT o.id,
    o.organization_name,
    o.contact_person,
    o.contact_number,
    o.email,
    o.details_jsonb,
    o.notes,
    o.is_active,
    o.source,
    o.source_detail,
    o.created_by_user_id,
    o.updated_by_user_id,
    o.created_at,
    o.updated_at,
    COALESCE(oa.organization_aliases, '[]'::jsonb) AS organization_aliases
   FROM (public.organizations o
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', a.id, 'alias_name', a.alias_name, 'is_active', a.is_active) ORDER BY a.is_active DESC NULLS LAST, a.alias_name) AS organization_aliases
           FROM public.organization_aliases a
          WHERE ((a.organization_id = o.id) AND (a.is_active IS TRUE))) oa ON (true))
  WHERE (o.is_active IS TRUE);


--
-- Name: VIEW v_organization_details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_organization_details IS 'Organization details/search read model with active aliases for frontend use.';


--
-- Name: v_organization_search; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_organization_search AS
 SELECT o.id,
    o.organization_name,
    COALESCE(oa.aliases, '[]'::jsonb) AS aliases
   FROM (public.organizations o
     LEFT JOIN LATERAL ( SELECT jsonb_agg(a.alias_name ORDER BY a.is_active DESC NULLS LAST, a.alias_name) AS aliases
           FROM public.organization_aliases a
          WHERE (a.organization_id = o.id)) oa ON (true))
  WHERE (o.is_active IS TRUE);


--
-- Name: VIEW v_organization_search; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_organization_search IS 'Authenticated-only organization search view exposing non-sensitive organization identity and aliases.';


--
-- Name: v_person_details; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_person_details AS
 SELECT p.id,
    p.first_name,
    p.middle_name,
    p.last_name,
    p.suffix,
    p.full_name,
    p.gender,
    p.birth_date,
    p.notes,
    p.is_active,
    p.created_at,
    p.updated_at,
    p.person_descriptor,
    p.age,
    p.is_minor,
    p.is_senior,
    p.is_pwd,
    COALESCE(pa_alias.person_aliases, '[]'::jsonb) AS person_aliases,
    COALESCE(pa_addr.person_addresses, '[]'::jsonb) AS person_addresses
   FROM ((public.persons p
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('alias_name', a.alias_name, 'alias_type', a.alias_type, 'is_active', a.is_active) ORDER BY a.is_active DESC NULLS LAST, a.alias_name) AS person_aliases
           FROM public.person_aliases a
          WHERE (a.person_id = p.id)) pa_alias ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', paddr.id, 'address_id', addr.id, 'address_type_id', paddr.address_type_id, 'is_primary', paddr.is_primary, 'remarks', paddr.remarks, 'addresses',
                CASE
                    WHEN (addr.id IS NULL) THEN NULL::jsonb
                    ELSE jsonb_build_object('id', addr.id, 'address_id', addr.id, 'barangay', addr.barangay, 'city', addr.city, 'country', addr.country, 'line1', addr.line1, 'line2', addr.line2, 'province', addr.province, 'region', addr.region, 'zip_code', addr.zip_code)
                END) ORDER BY paddr.is_primary DESC NULLS LAST, paddr.id) AS person_addresses
           FROM (public.person_addresses paddr
             LEFT JOIN public.addresses addr ON ((addr.id = paddr.address_id)))
          WHERE (paddr.person_id = p.id)) pa_addr ON (true));


--
-- Name: VIEW v_person_details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_person_details IS 'Person details page read model with aliases and addresses, including concrete address_id for existing-person address reuse.';


--
-- Name: v_recent_audit_logs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_recent_audit_logs AS
 SELECT id,
    actor_user_id,
    entity_name,
    entity_id,
    action,
    old_data,
    new_data,
    ip_address,
    created_at,
    case_id,
    summary,
    metadata
   FROM public.audit_logs;


--
-- Name: VIEW v_recent_audit_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_recent_audit_logs IS 'Frontend audit-log read view; security policies will be implemented later.';


--
-- Name: v_ref_address_types; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_address_types AS
 SELECT id,
    code,
    display_label,
    is_active
   FROM public.address_types
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_address_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_address_types IS 'Frontend reference view; security policies will be implemented later.';


--
-- Name: v_ref_case_classifications; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_case_classifications AS
 SELECT id,
    display_label,
    description,
    is_active,
    created_at
   FROM public.case_classifications
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_case_classifications; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_case_classifications IS 'Frontend reference view; security policies will be implemented later.';


--
-- Name: v_ref_case_event_types; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_case_event_types AS
 SELECT id,
    code,
    display_label,
    category,
    description,
    sort_order,
    is_active
   FROM public.case_event_types
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_case_event_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_case_event_types IS 'Frontend reference view for active case timeline/activity event types.';


--
-- Name: v_ref_case_stages; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_case_stages AS
 SELECT id,
    code,
    display_label,
    sort_order,
    is_final_stage,
    is_milestone,
    is_active,
    created_at,
    updated_at
   FROM public.case_stages
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_case_stages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_case_stages IS 'Frontend reference view for active case workflow stages.';


--
-- Name: v_ref_case_statuses; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_case_statuses AS
 SELECT id,
    code,
    display_label,
    sort_order,
    is_final,
    is_milestone,
    is_active,
    created_at
   FROM public.case_statuses
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_case_statuses; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_case_statuses IS 'Frontend reference view; security policies will be implemented later.';


--
-- Name: v_ref_courts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_courts AS
 SELECT id,
    code,
    name,
    court_type,
    is_active,
    created_at,
    updated_at
   FROM public.courts
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_courts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_courts IS 'Frontend reference view; security policies will be implemented later.';


--
-- Name: v_ref_docket_types; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_docket_types AS
 SELECT id,
    name,
    prefix,
    sort_order,
    is_active,
    created_at
   FROM public.docket_types
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_docket_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_docket_types IS 'Frontend reference view; security policies will be implemented later.';


--
-- Name: v_ref_participant_roles; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_participant_roles AS
 SELECT id,
    code,
    display_label,
    is_active
   FROM public.participant_roles
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_participant_roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_participant_roles IS 'Frontend reference view; security policies will be implemented later.';


--
-- Name: v_ref_prosecutors; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_prosecutors AS
 SELECT pr.id,
    pr.first_name,
    pr.middle_name,
    pr.last_name,
    pr.suffix,
    pr.full_name,
    pr.short_name,
    pr.position_id,
    pr.is_active,
    pr.created_at,
    p.code AS position_code,
    p.title AS position_title,
    p.group_type AS position_group_type
   FROM (public.prosecutors pr
     LEFT JOIN public.positions p ON ((p.id = pr.position_id)))
  WHERE (pr.is_active = true);


--
-- Name: VIEW v_ref_prosecutors; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_prosecutors IS 'Frontend reference view; security policies will be implemented later.';


--
-- Name: v_ref_users; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_users AS
 SELECT id,
    prosecutor_id,
    staff_id,
    email,
    is_active,
    last_login_at,
    created_at,
    updated_at,
    auth_user_id
   FROM public.users
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_users; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_users IS 'Frontend user lookup view; security policies will be implemented later.';


--
-- Name: v_ref_violations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ref_violations AS
 SELECT id,
    reference_code,
    title,
    short_label,
    description,
    law_reference,
    is_active,
    created_by_user_id,
    created_at,
    canonical_title
   FROM public.violations
  WHERE (is_active = true);


--
-- Name: VIEW v_ref_violations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ref_violations IS 'Frontend reference view; security policies will be implemented later.';


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
-- Name: _rls_policy_backup id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._rls_policy_backup ALTER COLUMN id SET DEFAULT nextval('public._rls_policy_backup_id_seq'::regclass);


--
-- Name: _rls_table_state_backup id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._rls_table_state_backup ALTER COLUMN id SET DEFAULT nextval('public._rls_table_state_backup_id_seq'::regclass);


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
-- Name: case_stage_colors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_colors ALTER COLUMN id SET DEFAULT nextval('public.case_stage_colors_id_seq'::regclass);


--
-- Name: case_stage_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_history ALTER COLUMN id SET DEFAULT nextval('public.case_stage_history_id_seq'::regclass);


--
-- Name: case_stages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stages ALTER COLUMN id SET DEFAULT nextval('public.case_stages_id_seq'::regclass);


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
-- Name: _rls_policy_backup _rls_policy_backup_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._rls_policy_backup
    ADD CONSTRAINT _rls_policy_backup_pkey PRIMARY KEY (id);


--
-- Name: _rls_table_state_backup _rls_table_state_backup_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._rls_table_state_backup
    ADD CONSTRAINT _rls_table_state_backup_pkey PRIMARY KEY (id);


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
-- Name: case_court_filings case_court_filings_case_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_case_event_id_key UNIQUE (case_event_id);


--
-- Name: case_court_filings case_court_filings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_pkey PRIMARY KEY (id);


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
-- Name: case_participant_corrections case_participant_corrections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_pkey PRIMARY KEY (id);


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
-- Name: case_resolution_approval_actions case_resolution_approval_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approval_actions
    ADD CONSTRAINT case_resolution_approval_actions_pkey PRIMARY KEY (id);


--
-- Name: case_resolution_approvals case_resolution_approvals_case_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_case_event_id_key UNIQUE (case_event_id);


--
-- Name: case_resolution_approvals case_resolution_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_pkey PRIMARY KEY (id);


--
-- Name: case_resolution_charge_actions case_resolution_charge_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_charge_actions
    ADD CONSTRAINT case_resolution_charge_actions_pkey PRIMARY KEY (id);


--
-- Name: case_resolutions case_resolutions_case_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolutions
    ADD CONSTRAINT case_resolutions_case_event_id_key UNIQUE (case_event_id);


--
-- Name: case_resolutions case_resolutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolutions
    ADD CONSTRAINT case_resolutions_pkey PRIMARY KEY (id);


--
-- Name: case_stage_colors case_stage_colors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_colors
    ADD CONSTRAINT case_stage_colors_pkey PRIMARY KEY (id);


--
-- Name: case_stage_colors case_stage_colors_stage_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_colors
    ADD CONSTRAINT case_stage_colors_stage_id_key UNIQUE (stage_id);


--
-- Name: case_stage_history case_stage_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_history
    ADD CONSTRAINT case_stage_history_pkey PRIMARY KEY (id);


--
-- Name: case_stages case_stages_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stages
    ADD CONSTRAINT case_stages_code_key UNIQUE (code);


--
-- Name: case_stages case_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stages
    ADD CONSTRAINT case_stages_pkey PRIMARY KEY (id);


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
-- Name: contact_informations contact_informations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_informations
    ADD CONSTRAINT contact_informations_pkey PRIMARY KEY (id);


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
-- Name: organization_addresses organization_addresses_organization_id_address_id_address_type_; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_addresses
    ADD CONSTRAINT organization_addresses_organization_id_address_id_address_type_ UNIQUE (organization_id, address_id, address_type_id);


--
-- Name: organization_addresses organization_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_addresses
    ADD CONSTRAINT organization_addresses_pkey PRIMARY KEY (id);


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
-- Name: participant_contact_informations participant_contact_informations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_contact_informations
    ADD CONSTRAINT participant_contact_informations_pkey PRIMARY KEY (id);


--
-- Name: participant_contact_informations participant_contact_informations_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_contact_informations
    ADD CONSTRAINT participant_contact_informations_unique UNIQUE (case_participant_id, contact_information_id);


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
-- Name: contact_informations_contact_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_informations_contact_type_idx ON public.contact_informations USING btree (contact_type);


--
-- Name: idx_audit_logs_action_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_action_time ON public.audit_logs USING btree (action, created_at DESC);


--
-- Name: idx_audit_logs_actor_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_actor_time ON public.audit_logs USING btree (actor_user_id, created_at DESC);


--
-- Name: idx_audit_logs_case_id_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_case_id_time ON public.audit_logs USING btree (case_id, created_at DESC);


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
-- Name: idx_case_court_filings_approval_action_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_court_filings_approval_action_id ON public.case_court_filings USING btree (case_resolution_approval_action_id) WHERE (is_voided = false);


--
-- Name: idx_case_court_filings_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_court_filings_case_id ON public.case_court_filings USING btree (case_id);


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
-- Name: idx_case_events_case_stage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_events_case_stage_id ON public.case_events USING btree (case_stage_id);


--
-- Name: idx_case_events_case_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_events_case_status_id ON public.case_events USING btree (case_status_id);


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
-- Name: idx_case_participant_corrections_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_corrections_case_id ON public.case_participant_corrections USING btree (case_id, corrected_at DESC);


--
-- Name: idx_case_participant_corrections_case_participant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participant_corrections_case_participant_id ON public.case_participant_corrections USING btree (case_participant_id, corrected_at DESC);


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
-- Name: idx_case_participants_organization_id_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_organization_id_case_id ON public.case_participants USING btree (organization_id, case_id) WHERE (organization_id IS NOT NULL);


--
-- Name: idx_case_participants_person_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_person_case ON public.case_participants USING btree (person_id, case_id);


--
-- Name: idx_case_participants_person_id_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_person_id_case_id ON public.case_participants USING btree (person_id, case_id) WHERE (person_id IS NOT NULL);


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
-- Name: idx_case_private_details_current_case_stage_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_private_details_current_case_stage_date ON public.case_private_details USING btree (current_case_stage_date);


--
-- Name: idx_case_private_details_current_case_stage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_private_details_current_case_stage_id ON public.case_private_details USING btree (current_case_stage_id);


--
-- Name: idx_case_private_details_current_case_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_private_details_current_case_status_id ON public.case_private_details USING btree (current_case_status_id);


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
-- Name: idx_case_resolution_approval_actions_approval_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_resolution_approval_actions_approval_id ON public.case_resolution_approval_actions USING btree (approval_id);


--
-- Name: idx_case_resolution_approval_actions_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_resolution_approval_actions_case_id ON public.case_resolution_approval_actions USING btree (case_id);


--
-- Name: idx_case_resolution_approvals_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_resolution_approvals_case_id ON public.case_resolution_approvals USING btree (case_id);


--
-- Name: idx_case_resolution_charge_actions_resolution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_resolution_charge_actions_resolution_id ON public.case_resolution_charge_actions USING btree (case_resolution_id);


--
-- Name: idx_case_resolutions_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_resolutions_case_id ON public.case_resolutions USING btree (case_id);


--
-- Name: idx_case_stage_history_case_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_stage_history_case_event_id ON public.case_stage_history USING btree (case_event_id);


--
-- Name: idx_case_stage_history_case_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_stage_history_case_time ON public.case_stage_history USING btree (case_id, changed_at DESC);


--
-- Name: idx_case_stage_history_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_stage_history_stage ON public.case_stage_history USING btree (to_stage_id);


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
-- Name: idx_clearance_phonetic_tokens_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_phonetic_tokens_organization ON public.clearance_phonetic_name_tokens USING btree (organization_id);


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
-- Name: idx_clearance_possible_tokens_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clearance_possible_tokens_organization ON public.clearance_possible_name_tokens USING btree (organization_id);


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

CREATE UNIQUE INDEX one_active_assignment_per_case ON public.case_assignments USING btree (case_id) WHERE ((unassigned_at IS NULL) AND (is_voided IS FALSE));


--
-- Name: one_active_prosecutor_staff_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_prosecutor_staff_pair ON public.prosecutor_staff_assignments USING btree (prosecutor_id, staff_id) WHERE (end_date IS NULL);


--
-- Name: organization_addresses_address_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_addresses_address_id_idx ON public.organization_addresses USING btree (address_id);


--
-- Name: organization_addresses_organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_addresses_organization_id_idx ON public.organization_addresses USING btree (organization_id);


--
-- Name: participant_contact_informations_case_participant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX participant_contact_informations_case_participant_id_idx ON public.participant_contact_informations USING btree (case_participant_id);


--
-- Name: participant_contact_informations_contact_information_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX participant_contact_informations_contact_information_id_idx ON public.participant_contact_informations USING btree (contact_information_id);


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
-- Name: audit_logs audit_logs_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id);


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
-- Name: case_addresses case_addresses_deleted_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_addresses
    ADD CONSTRAINT case_addresses_deleted_by_user_id_fkey FOREIGN KEY (deleted_by_user_id) REFERENCES public.users(id);


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
-- Name: case_assignments case_assignments_unassigned_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_unassigned_by_user_id_fkey FOREIGN KEY (unassigned_by_user_id) REFERENCES public.users(id);


--
-- Name: case_assignments case_assignments_voided_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_assignments
    ADD CONSTRAINT case_assignments_voided_by_user_id_fkey FOREIGN KEY (voided_by_user_id) REFERENCES public.users(id);


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
-- Name: case_court_filings case_court_filings_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id);


--
-- Name: case_court_filings case_court_filings_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id);


--
-- Name: case_court_filings case_court_filings_case_resolution_approval_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_case_resolution_approval_action_id_fkey FOREIGN KEY (case_resolution_approval_action_id) REFERENCES public.case_resolution_approval_actions(id);


--
-- Name: case_court_filings case_court_filings_case_resolution_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_case_resolution_approval_id_fkey FOREIGN KEY (case_resolution_approval_id) REFERENCES public.case_resolution_approvals(id);


--
-- Name: case_court_filings case_court_filings_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id);


--
-- Name: case_court_filings case_court_filings_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_court_filings case_court_filings_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_court_filings case_court_filings_voided_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_court_filings
    ADD CONSTRAINT case_court_filings_voided_by_user_id_fkey FOREIGN KEY (voided_by_user_id) REFERENCES public.users(id);


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
-- Name: case_events case_events_case_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_case_stage_id_fkey FOREIGN KEY (case_stage_id) REFERENCES public.case_stages(id);


--
-- Name: case_events case_events_case_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_events
    ADD CONSTRAINT case_events_case_status_id_fkey FOREIGN KEY (case_status_id) REFERENCES public.case_statuses(id);


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
-- Name: case_participant_corrections case_participant_corrections_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id);


--
-- Name: case_participant_corrections case_participant_corrections_case_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_case_participant_id_fkey FOREIGN KEY (case_participant_id) REFERENCES public.case_participants(id);


--
-- Name: case_participant_corrections case_participant_corrections_corrected_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_corrected_by_user_id_fkey FOREIGN KEY (corrected_by_user_id) REFERENCES public.users(id);


--
-- Name: case_participant_corrections case_participant_corrections_new_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_new_organization_id_fkey FOREIGN KEY (new_organization_id) REFERENCES public.organizations(id);


--
-- Name: case_participant_corrections case_participant_corrections_new_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_new_person_id_fkey FOREIGN KEY (new_person_id) REFERENCES public.persons(id);


--
-- Name: case_participant_corrections case_participant_corrections_old_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_old_organization_id_fkey FOREIGN KEY (old_organization_id) REFERENCES public.organizations(id);


--
-- Name: case_participant_corrections case_participant_corrections_old_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_participant_corrections
    ADD CONSTRAINT case_participant_corrections_old_person_id_fkey FOREIGN KEY (old_person_id) REFERENCES public.persons(id);


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
-- Name: case_private_details case_private_details_current_case_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_private_details
    ADD CONSTRAINT case_private_details_current_case_stage_id_fkey FOREIGN KEY (current_case_stage_id) REFERENCES public.case_stages(id);


--
-- Name: case_private_details case_private_details_current_case_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_private_details
    ADD CONSTRAINT case_private_details_current_case_status_id_fkey FOREIGN KEY (current_case_status_id) REFERENCES public.case_statuses(id);


--
-- Name: case_private_details case_private_details_current_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_private_details
    ADD CONSTRAINT case_private_details_current_status_id_fkey FOREIGN KEY (current_status_id) REFERENCES public.case_statuses(id);


--
-- Name: case_resolution_approval_actions case_resolution_approval_acti_source_resolution_charge_act_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approval_actions
    ADD CONSTRAINT case_resolution_approval_acti_source_resolution_charge_act_fkey FOREIGN KEY (source_resolution_charge_action_id) REFERENCES public.case_resolution_charge_actions(id);


--
-- Name: case_resolution_approval_actions case_resolution_approval_actions_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approval_actions
    ADD CONSTRAINT case_resolution_approval_actions_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES public.case_resolution_approvals(id) ON DELETE CASCADE;


--
-- Name: case_resolution_approval_actions case_resolution_approval_actions_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approval_actions
    ADD CONSTRAINT case_resolution_approval_actions_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id);


--
-- Name: case_resolution_approval_actions case_resolution_approval_actions_case_violation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approval_actions
    ADD CONSTRAINT case_resolution_approval_actions_case_violation_id_fkey FOREIGN KEY (case_violation_id) REFERENCES public.case_violations(id);


--
-- Name: case_resolution_approval_actions case_resolution_approval_actions_violation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approval_actions
    ADD CONSTRAINT case_resolution_approval_actions_violation_id_fkey FOREIGN KEY (violation_id) REFERENCES public.violations(id);


--
-- Name: case_resolution_approvals case_resolution_approvals_approved_by_prosecutor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_approved_by_prosecutor_id_fkey FOREIGN KEY (approved_by_prosecutor_id) REFERENCES public.prosecutors(id);


--
-- Name: case_resolution_approvals case_resolution_approvals_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id);


--
-- Name: case_resolution_approvals case_resolution_approvals_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id);


--
-- Name: case_resolution_approvals case_resolution_approvals_case_resolution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_case_resolution_id_fkey FOREIGN KEY (case_resolution_id) REFERENCES public.case_resolutions(id);


--
-- Name: case_resolution_approvals case_resolution_approvals_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_resolution_approvals case_resolution_approvals_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_resolution_approvals case_resolution_approvals_voided_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_approvals
    ADD CONSTRAINT case_resolution_approvals_voided_by_user_id_fkey FOREIGN KEY (voided_by_user_id) REFERENCES public.users(id);


--
-- Name: case_resolution_charge_actions case_resolution_charge_actions_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_charge_actions
    ADD CONSTRAINT case_resolution_charge_actions_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id);


--
-- Name: case_resolution_charge_actions case_resolution_charge_actions_case_resolution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_charge_actions
    ADD CONSTRAINT case_resolution_charge_actions_case_resolution_id_fkey FOREIGN KEY (case_resolution_id) REFERENCES public.case_resolutions(id);


--
-- Name: case_resolution_charge_actions case_resolution_charge_actions_case_violation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_charge_actions
    ADD CONSTRAINT case_resolution_charge_actions_case_violation_id_fkey FOREIGN KEY (case_violation_id) REFERENCES public.case_violations(id);


--
-- Name: case_resolution_charge_actions case_resolution_charge_actions_violation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolution_charge_actions
    ADD CONSTRAINT case_resolution_charge_actions_violation_id_fkey FOREIGN KEY (violation_id) REFERENCES public.violations(id);


--
-- Name: case_resolutions case_resolutions_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolutions
    ADD CONSTRAINT case_resolutions_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id);


--
-- Name: case_resolutions case_resolutions_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolutions
    ADD CONSTRAINT case_resolutions_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id);


--
-- Name: case_resolutions case_resolutions_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolutions
    ADD CONSTRAINT case_resolutions_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: case_resolutions case_resolutions_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolutions
    ADD CONSTRAINT case_resolutions_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: case_resolutions case_resolutions_voided_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_resolutions
    ADD CONSTRAINT case_resolutions_voided_by_user_id_fkey FOREIGN KEY (voided_by_user_id) REFERENCES public.users(id);


--
-- Name: case_stage_colors case_stage_colors_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_colors
    ADD CONSTRAINT case_stage_colors_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.case_stages(id) ON DELETE CASCADE;


--
-- Name: case_stage_history case_stage_history_case_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_history
    ADD CONSTRAINT case_stage_history_case_event_id_fkey FOREIGN KEY (case_event_id) REFERENCES public.case_events(id) ON DELETE SET NULL;


--
-- Name: case_stage_history case_stage_history_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_history
    ADD CONSTRAINT case_stage_history_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_stage_history case_stage_history_changed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_history
    ADD CONSTRAINT case_stage_history_changed_by_user_id_fkey FOREIGN KEY (changed_by_user_id) REFERENCES public.users(id);


--
-- Name: case_stage_history case_stage_history_from_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_history
    ADD CONSTRAINT case_stage_history_from_stage_id_fkey FOREIGN KEY (from_stage_id) REFERENCES public.case_stages(id);


--
-- Name: case_stage_history case_stage_history_to_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_stage_history
    ADD CONSTRAINT case_stage_history_to_stage_id_fkey FOREIGN KEY (to_stage_id) REFERENCES public.case_stages(id);


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
-- Name: case_violations case_violations_deleted_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_violations
    ADD CONSTRAINT case_violations_deleted_by_user_id_fkey FOREIGN KEY (deleted_by_user_id) REFERENCES public.users(id);


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
-- Name: notes notes_deleted_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_deleted_by_user_id_fkey FOREIGN KEY (deleted_by_user_id) REFERENCES public.users(id);


--
-- Name: organization_addresses organization_addresses_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_addresses
    ADD CONSTRAINT organization_addresses_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id) ON DELETE RESTRICT;


--
-- Name: organization_addresses organization_addresses_address_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_addresses
    ADD CONSTRAINT organization_addresses_address_type_id_fkey FOREIGN KEY (address_type_id) REFERENCES public.address_types(id) ON DELETE RESTRICT;


--
-- Name: organization_addresses organization_addresses_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_addresses
    ADD CONSTRAINT organization_addresses_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


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
-- Name: participant_contact_informations participant_contact_informations_case_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_contact_informations
    ADD CONSTRAINT participant_contact_informations_case_participant_id_fkey FOREIGN KEY (case_participant_id) REFERENCES public.case_participants(id) ON DELETE CASCADE;


--
-- Name: participant_contact_informations participant_contact_informations_contact_information_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_contact_informations
    ADD CONSTRAINT participant_contact_informations_contact_information_id_fkey FOREIGN KEY (contact_information_id) REFERENCES public.contact_informations(id) ON DELETE CASCADE;


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
-- Name: persons persons_replaced_by_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_replaced_by_person_id_fkey FOREIGN KEY (replaced_by_person_id) REFERENCES public.persons(id) NOT VALID;


--
-- Name: persons persons_voided_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_voided_by_user_id_fkey FOREIGN KEY (voided_by_user_id) REFERENCES public.users(id) NOT VALID;


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

\unrestrict t7blyZqqpaxPa9pImFQQnS3OZKJcXpLd2GvRFQn9O77jrdsEtcm0OE8pH0btyb4

