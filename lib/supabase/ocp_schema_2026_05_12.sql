--
-- PostgreSQL database dump
--

\restrict bepKbqTd38qXfIynPDrwsWy3CTpMO9IxrS5ovkaXg9tI0asbfTqcIQyKjmF9wXM

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

    IF n >= 3 AND tokens[n - 1] ~ '^[A-ZÑ]\\.?$' THEN
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

CREATE FUNCTION public.legacy_gender_normalized(p_text text) RETURNS character varying
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

CREATE FUNCTION public.legacy_org_type(p_text text, p_descriptor text DEFAULT NULL::text) RETURNS character varying
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
    IF block IS NULL THEN
        RETURN;
    END IF;

    work := replace(block, E'\r', E'\n');

    -- Put enumerated entries on separate lines even if the source cell has mixed spacing.
    -- Keep the number with the entry temporarily so it can be stripped cleanly below.
    work := regexp_replace(work, '(^|[[:space:]])([0-9]+)[[:space:]]*[\.)][[:space:]]*', E'\n\\2. ', 'g');
    work := regexp_replace(work, E'\n+', E'\n', 'g');

    FOR line IN SELECT * FROM regexp_split_to_table(work, E'\n+') LOOP
        cleaned := public.legacy_clean_text(line);
        IF cleaned IS NULL THEN
            CONTINUE;
        END IF;

        cleaned := regexp_replace(cleaned, '^\s*[0-9]+\s*[\.)]\s*', '', 'g');
        cleaned := regexp_replace(cleaned, '\s+', ' ', 'g');
        cleaned := btrim(cleaned, ' ,.;:-');

        IF cleaned IS NULL OR cleaned = '' THEN
            CONTINUE;
        END IF;

        n := n + 1;
        seq := n;
        raw_representative := cleaned;

        -- Collective/non-person rows should not be inserted into persons.first_name.
        -- They are still detectable from the raw relationship text and can be reviewed later.
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
-- Name: search_clearance_records(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_clearance_records(p_query text, p_search_type text DEFAULT 'all'::text, p_limit integer DEFAULT 50) RETURNS TABLE(person_id integer, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamp with time zone, confidence_score integer, match_details text, match_type text, role_label text)
    LANGUAGE sql STABLE
    AS $$
  with normalized as (
    select
      q,
      least(greatest(coalesce(p_limit, 50), 1), 100) as safe_limit,
      case when p_search_type in ('name', 'alias', 'all') then p_search_type else 'all' end as search_type,
      q_norm,
      coalesce(q_tokens, array[]::text[]) as q_tokens,
      cardinality(coalesce(q_tokens, array[]::text[])) as q_token_count
    from (
      select
        nullif(trim(p_query), '') as q,
        nullif(trim(regexp_replace(lower(trim(p_query)), '[^a-z0-9]+', ' ', 'g')), '') as q_norm
    ) input
    left join lateral (
      select array_agg(token order by token) as q_tokens
      from regexp_split_to_table(coalesce(input.q_norm, ''), ' ') as token
      where length(token) > 1
    ) query_tokens on true
  ), alias_rows as (
    select
      pa.person_id,
      pa.alias_name,
      greatest(
        case when nullif(trim(regexp_replace(lower(coalesce(pa.alias_name, '')), '[^a-z0-9]+', ' ', 'g')), '') = normalized.q_norm then 0.98 else 0 end,
        case when alias_metrics.all_query_tokens_exact and normalized.q_token_count >= 2 then 0.92 else 0 end,
        case when alias_metrics.all_query_tokens_exact and normalized.q_token_count = 1 then 0.74 else 0 end,
        case when alias_metrics.all_query_tokens_prefix and normalized.q_token_count >= 2 then 0.84 else 0 end,
        case when alias_metrics.all_query_tokens_prefix and normalized.q_token_count = 1 then 0.80 else 0 end,
        case when alias_metrics.phonetic_token_matches = normalized.q_token_count and normalized.q_token_count >= 2 then 0.70 else 0 end,
        case when alias_metrics.phonetic_token_matches > 0 then 0.56 else 0 end,
        least(similarity(coalesce(pa.alias_name, ''), normalized.q), 0.86),
        least(alias_metrics.best_token_similarity * 0.95, 0.72)
      ) as alias_score,
      case
        when nullif(trim(regexp_replace(lower(coalesce(pa.alias_name, '')), '[^a-z0-9]+', ' ', 'g')), '') = normalized.q_norm then 'Exact alias match: ' || pa.alias_name
        when alias_metrics.all_query_tokens_exact then 'Exact alias token match: ' || pa.alias_name
        when alias_metrics.all_query_tokens_prefix then 'Alias prefix match: ' || pa.alias_name
        when alias_metrics.phonetic_token_matches > 0 then 'Phonetic alias token match: ' || pa.alias_name
        else 'Alias fuzzy match: ' || pa.alias_name
      end as alias_details
    from public.person_aliases pa
    cross join normalized
    left join lateral (
      select
        coalesce(alias_tokens.tokens, array[]::text[]) as tokens,
        normalized.q_token_count > 0
          and normalized.q_tokens <@ coalesce(alias_tokens.tokens, array[]::text[]) as all_query_tokens_exact,
        normalized.q_token_count > 0
          and not exists (
            select 1
            from unnest(normalized.q_tokens) as query_token(value)
            where length(query_token.value) < 3
              or not exists (
                select 1
                from unnest(coalesce(alias_tokens.tokens, array[]::text[])) as alias_token(value)
                where alias_token.value like query_token.value || '%'
                  or replace(alias_token.value, 'v', 'b') like replace(query_token.value, 'v', 'b') || '%'
              )
          ) as all_query_tokens_prefix,
        coalesce((
          select count(*)::integer
          from unnest(normalized.q_tokens) as query_token(value)
          where length(query_token.value) >= 4
            and exists (
              select 1
              from unnest(coalesce(alias_tokens.tokens, array[]::text[])) as alias_token(value)
              where length(alias_token.value) >= 4
                and (
                  dmetaphone(alias_token.value) = dmetaphone(query_token.value)
                  or dmetaphone(replace(alias_token.value, 'v', 'b')) = dmetaphone(replace(query_token.value, 'v', 'b'))
                )
            )
        ), 0) as phonetic_token_matches,
        coalesce((
          select max(greatest(
            similarity(alias_token.value, query_token.value),
            similarity(replace(alias_token.value, 'v', 'b'), replace(query_token.value, 'v', 'b'))
          ))
          from unnest(normalized.q_tokens) as query_token(value)
          cross join unnest(coalesce(alias_tokens.tokens, array[]::text[])) as alias_token(value)
        ), 0) as best_token_similarity
      from (
        select array_agg(token order by token) as tokens
        from regexp_split_to_table(
          coalesce(nullif(trim(regexp_replace(lower(coalesce(pa.alias_name, '')), '[^a-z0-9]+', ' ', 'g')), ''), ''),
          ' '
        ) as token
        where length(token) > 1
      ) alias_tokens
    ) alias_metrics on true
    where pa.is_active
      and normalized.q is not null
      and normalized.search_type in ('alias', 'all')
  ), candidate_aliases as (
    select
      person_id,
      array_agg(alias_name order by alias_name) as aliases,
      max(alias_score) as alias_score,
      (array_agg(alias_name order by alias_score desc, alias_name))[1] as best_alias,
      (array_agg(alias_details order by alias_score desc, alias_name))[1] as alias_details
    from alias_rows
    group by person_id
  ), base as (
    select
      p.id as person_id,
      cp.case_id,
      concat_ws('-', dt.prefix, c.docket_year::text, lpad(c.docket_number::text, 4, '0')) as docket_number,
      concat_ws('-', dt.prefix, c.docket_year::text, lpad(c.docket_number::text, 4, '0')) as case_number,
      p.full_name,
      coalesce(ca.aliases, array[]::text[]) as aliases,
      coalesce(ca.alias_score, 0) as alias_score,
      ca.alias_details,
      coalesce(cs.display_label, cs.code, 'Pending') as status,
      coalesce(csh.changed_at, c.updated_at, c.created_at) as last_updated,
      coalesce(pr.display_label, pr.code, 'Participant') as role_label,
      normalized.safe_limit,
      normalized.search_type,
      normalized.q,
      normalized.q_norm,
      normalized.q_tokens,
      normalized.q_token_count
    from normalized
    join public.persons p on normalized.q is not null and p.is_active
    join public.case_participants cp on cp.person_id = p.id
    join public.cases c on c.id = cp.case_id and not c.is_archived
    join public.docket_types dt on dt.id = c.docket_type_id
    left join public.participant_roles pr on pr.id = cp.role_id
    left join candidate_aliases ca on ca.person_id = p.id
    left join lateral (
      select h.to_status_id, h.changed_at
      from public.case_status_history h
      where h.case_id = c.id
      order by h.changed_at desc
      limit 1
    ) csh on true
    left join public.case_statuses cs on cs.id = csh.to_status_id
  ), scored as (
    select
      base.*,
      name_metrics.exact_name_match,
      name_metrics.exact_unordered_name_match,
      name_metrics.all_query_tokens_exact,
      name_metrics.all_query_tokens_prefix,
      name_metrics.phonetic_token_matches,
      name_metrics.best_prefix_token,
      greatest(
        case when base.search_type in ('name', 'all') and name_metrics.exact_name_match then 1.00 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.exact_unordered_name_match then 1.00 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_exact and base.q_token_count >= 2 then 0.94 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_exact and base.q_token_count = 1 then 0.76 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_prefix and base.q_token_count >= 2 then 0.86 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_prefix and base.q_token_count = 1 then 0.82 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.phonetic_token_matches = base.q_token_count and base.q_token_count >= 2 then 0.72 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.phonetic_token_matches > 0 then 0.58 else 0 end,
        case when base.search_type in ('name', 'all') then least(similarity(coalesce(base.full_name, ''), base.q), 0.89) else 0 end,
        case when base.search_type in ('name', 'all') then least(name_metrics.best_token_similarity * 0.95, 0.74) else 0 end
      ) as name_score
    from base
    left join lateral (
      select
        nullif(trim(regexp_replace(lower(coalesce(base.full_name, '')), '[^a-z0-9]+', ' ', 'g')), '') = base.q_norm as exact_name_match,
        base.q_token_count > 0
          and base.q_token_count = cardinality(coalesce(name_tokens.tokens, array[]::text[]))
          and base.q_tokens = coalesce(name_tokens.tokens, array[]::text[]) as exact_unordered_name_match,
        base.q_token_count > 0
          and base.q_tokens <@ coalesce(name_tokens.tokens, array[]::text[]) as all_query_tokens_exact,
        base.q_token_count > 0
          and not exists (
            select 1
            from unnest(base.q_tokens) as query_token(value)
            where length(query_token.value) < 3
              or not exists (
                select 1
                from unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
                where name_token.value like query_token.value || '%'
                  or replace(name_token.value, 'v', 'b') like replace(query_token.value, 'v', 'b') || '%'
              )
          ) as all_query_tokens_prefix,
        coalesce((
          select count(*)::integer
          from unnest(base.q_tokens) as query_token(value)
          where length(query_token.value) >= 4
            and exists (
              select 1
              from unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
              where length(name_token.value) >= 4
                and (
                  dmetaphone(name_token.value) = dmetaphone(query_token.value)
                  or dmetaphone(replace(name_token.value, 'v', 'b')) = dmetaphone(replace(query_token.value, 'v', 'b'))
                )
            )
        ), 0) as phonetic_token_matches,
        (
          select name_token.value
          from unnest(base.q_tokens) as query_token(value)
          join unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
            on name_token.value like query_token.value || '%'
              or replace(name_token.value, 'v', 'b') like replace(query_token.value, 'v', 'b') || '%'
          order by length(name_token.value), name_token.value
          limit 1
        ) as best_prefix_token,
        coalesce((
          select max(greatest(
            similarity(name_token.value, query_token.value),
            similarity(replace(name_token.value, 'v', 'b'), replace(query_token.value, 'v', 'b'))
          ))
          from unnest(base.q_tokens) as query_token(value)
          cross join unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
        ), 0) as best_token_similarity
      from (
        select array_agg(token order by token) as tokens
        from regexp_split_to_table(
          coalesce(nullif(trim(regexp_replace(lower(coalesce(base.full_name, '')), '[^a-z0-9]+', ' ', 'g')), ''), ''),
          ' '
        ) as token
        where length(token) > 1
      ) name_tokens
    ) name_metrics on true
  ), ranked as (
    select
      *,
      greatest(name_score, alias_score) as raw_score
    from scored
  )
  select
    person_id,
    case_id,
    docket_number,
    case_number,
    full_name,
    aliases,
    status,
    last_updated,
    least(100, greatest(0, round(raw_score * 100)::integer)) as confidence_score,
    case
      when alias_score > name_score and alias_score >= 0.45 then alias_details
      when exact_name_match or exact_unordered_name_match then 'Exact name match: ' || full_name
      when all_query_tokens_exact then 'Exact name token match: ' || full_name
      when all_query_tokens_prefix then 'Name prefix match: ' || coalesce(best_prefix_token, full_name)
      when phonetic_token_matches > 0 then 'Phonetic token match: ' || full_name
      else 'Name fuzzy match: ' || full_name
    end as match_details,
    case
      when alias_score > name_score and alias_score >= 0.45 then 'alias'
      when exact_name_match or exact_unordered_name_match or (all_query_tokens_exact and q_token_count >= 2) then 'exact'
      when phonetic_token_matches > 0 and name_score <= 0.72 then 'phonetic'
      else 'fuzzy'
    end as match_type,
    role_label
  from ranked
  where q is not null
    and raw_score >= 0.45
  order by raw_score desc, last_updated desc, full_name
  limit (select safe_limit from normalized);
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
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
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

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
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
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
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
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
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
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

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
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

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
        ) filter (WHERE ppt.tablename IS NOT NULL AND ppt.tablename NOT LIKE '% %'),
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
  -- Count raw slot entries before apply_rls/subscription filter
  slot_count AS (
    SELECT count(*)::bigint AS cnt
    FROM w2j
    WHERE w2j.w2j_add_tables <> ''
  ),
  -- Apply RLS and filter as before
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
  -- Real rows with slot count attached
  SELECT rf.wal, rf.is_rls_enabled, rf.subscription_ids, rf.errors, sc.cnt
  FROM rls_filtered rf, slot_count sc

  UNION ALL

  -- Sentinel row: always returned when no real rows exist so Elixir can
  -- always read slot_changes_count. Identified by wal IS NULL.
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
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
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
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
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
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
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

            -- Set maximum number of entries for in filter
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

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

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
    code character varying(50) NOT NULL,
    display_label character varying(100) NOT NULL,
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
    line1 character varying(255),
    line2 character varying(255),
    barangay character varying(100),
    city character varying(100),
    province character varying(100),
    region character varying(100),
    zip_code character varying(20),
    country character varying(100) DEFAULT 'Philippines'::character varying,
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
    remarks text
);


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
    file_name character varying(255) NOT NULL,
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
    court_branch character varying(100),
    charge_filed text,
    criminal_case_number character varying(255),
    information_count integer,
    date_filed_in_court date,
    actual_filing_date date,
    court_status text,
    court_remarks text,
    needs_review boolean DEFAULT true NOT NULL,
    review_reason text,
    source character varying(100),
    legacy_source_file character varying(255),
    legacy_source_sheet character varying(100),
    legacy_row_number integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


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
    source character varying(100),
    legacy_source_file character varying(255),
    legacy_source_sheet character varying(100),
    legacy_row_number integer,
    legacy_raw_json jsonb,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


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
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    participant_order integer,
    organization_id integer,
    participant_kind text,
    display_name_snapshot text,
    source text DEFAULT 'MANUAL_ENTRY'::character varying NOT NULL,
    source_detail text,
    legacy_source_file text,
    legacy_source_sheet text,
    legacy_row_number integer,
    legacy_raw_text text
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
    status_date date
);


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
    code character varying(50) NOT NULL,
    display_label character varying(100) NOT NULL,
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
    source character varying(100),
    remarks text,
    gdrive_folder_id character varying(255),
    gdrive_folder_link character varying(2048),
    gdrive_folder_name character varying(255),
    gdrive_folder_status character varying(30) DEFAULT 'NOT_CREATED'::character varying NOT NULL,
    gdrive_folder_last_scanned_at timestamp with time zone,
    created_by_user_id bigint NOT NULL,
    updated_by_user_id bigint,
    is_archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    region_code character varying(20),
    docket_month_code character varying(10),
    legacy_source_file character varying(255),
    legacy_source_sheet character varying(100),
    legacy_row_number integer,
    legacy_raw_json jsonb,
    is_summary_procedure boolean DEFAULT false,
    summary_text text,
    CONSTRAINT chk_cases_gdrive_folder_status CHECK (((gdrive_folder_status)::text = ANY (ARRAY[('NOT_CREATED'::character varying)::text, ('ACTIVE'::character varying)::text, ('MISSING'::character varying)::text, ('PERMISSION_ERROR'::character varying)::text, ('ARCHIVED'::character varying)::text])))
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
-- Name: courts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courts (
    id bigint NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    court_type character varying(50),
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
-- Name: legacy_inq2022_import_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_inq2022_import_rows (
    id bigint NOT NULL,
    source_file text DEFAULT 'INQ2022.xlsx'::text NOT NULL,
    source_sheet text DEFAULT 'INQ22'::text NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    vs_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    violations_raw text,
    date_received_raw text,
    date_raffled_raw text,
    case_classification_raw text,
    case_minor_raw text,
    case_senior_raw text,
    case_pwd_raw text,
    prosecutor_raw text,
    date_approved_out_raw text,
    status_raw text,
    date_filed_in_court_raw text,
    actual_filing_date_in_court_raw text,
    court_raw text,
    charge_raw text,
    criminal_case_number_raw text,
    remarks_raw text,
    motion_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_remarks_raw text,
    days_pending_raw text,
    aging_60_below_raw text,
    aging_61_120_raw text,
    aging_121_365_raw text,
    aging_more_than_1_year_raw text,
    today_raw text,
    days_raw text,
    blank_col_42_raw text,
    court_status_raw text,
    raw_json jsonb,
    import_status text DEFAULT 'STAGED'::text NOT NULL,
    review_flags text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: legacy_inq2022_import_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_inq2022_import_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_inq2022_import_rows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_inq2022_import_rows_id_seq OWNED BY public.legacy_inq2022_import_rows.id;


--
-- Name: legacy_inv2022_import_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_inv2022_import_rows (
    id bigint NOT NULL,
    excel_row_number integer NOT NULL,
    row_kind text NOT NULL,
    source_file text NOT NULL,
    source_sheet text NOT NULL,
    region_raw text,
    docket_year_raw text,
    docket_month_raw text,
    docket_number_raw text,
    complainants_raw text,
    complainant_age_raw text,
    complainant_gender_raw text,
    complainant_minor_raw text,
    respondents_raw text,
    respondent_age_raw text,
    respondent_gender_raw text,
    respondent_minor_raw text,
    violation_raw text,
    date_received_raw text,
    date_raffled_raw text,
    case_classification_raw text,
    minor_flag_raw text,
    senior_raw text,
    pwd_raw text,
    summary_raw text,
    prosecutor_raw text,
    date_approved_raw text,
    status_raw text,
    date_filed_in_court_raw text,
    actual_filing_date_raw text,
    court_raw text,
    rtc_branch_raw text,
    charge_raw text,
    criminal_case_number_raw text,
    motion_raw text,
    motion_date_received_raw text,
    motion_filed_by_raw text,
    motion_status_raw text,
    motion_remarks_raw text,
    remarks_mtcc_raw text,
    court_status_raw text,
    raw_json_text text,
    import_status text DEFAULT 'STAGED'::text,
    review_flags text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: legacy_inv2022_import_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.legacy_inv2022_import_rows ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.legacy_inv2022_import_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


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
    code character varying(50) NOT NULL,
    display_label character varying(100) NOT NULL,
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
    alias_name character varying(255) NOT NULL,
    alias_type character varying(30) DEFAULT 'AKA'::character varying NOT NULL,
    source character varying(100) DEFAULT 'LEGACY_EXCEL'::character varying NOT NULL,
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
    code character varying(50) NOT NULL,
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
    first_name character varying(100) NOT NULL,
    middle_name character varying(100),
    last_name character varying(100) NOT NULL,
    suffix character varying(20),
    full_name character varying(255) NOT NULL,
    short_name character varying(150),
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
    code character varying(50) NOT NULL,
    display_label character varying(100) NOT NULL,
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
    first_name character varying(100) NOT NULL,
    middle_name character varying(100),
    last_name character varying(100) NOT NULL,
    suffix character varying(20),
    full_name character varying(255) NOT NULL,
    short_name character varying(150),
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
    CONSTRAINT one_user_identity CHECK (((prosecutor_id IS NOT NULL) <> (staff_id IS NOT NULL)))
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

CREATE VIEW public.v_case_participants_long_term AS
 SELECT cp.id AS case_participant_id,
    cp.case_id,
    cp.role_id,
    pr.code AS role_code,
    pr.display_label AS role_label,
    cp.participant_order,
    cp.participant_kind,
    cp.person_id,
    cp.organization_id,
        CASE
            WHEN (cp.person_id IS NOT NULL) THEN p.full_name
            WHEN (cp.organization_id IS NOT NULL) THEN o.organization_name
            ELSE cp.display_name_snapshot
        END AS party_display_name,
        CASE
            WHEN (cp.person_id IS NOT NULL) THEN 'PERSON'::text
            WHEN (cp.organization_id IS NOT NULL) THEN 'ORGANIZATION'::text
            ELSE cp.participant_kind
        END AS party_type,
    p.first_name,
    p.middle_name,
    p.last_name,
    p.suffix,
    o.organization_type,
    cpa.age_text,
    cpa.age_years,
    cpa.age_basis_date,
    cpa.gender_text,
    cpa.gender_normalized,
    cpa.minor_text,
    cpa.is_minor_at_case,
    cpa.senior_text,
    cpa.is_senior_at_case,
    cpa.pwd_text,
    cpa.is_pwd_at_case,
    cp.remarks,
    cp.source,
    cp.legacy_source_file,
    cp.legacy_source_sheet,
    cp.legacy_row_number,
    cp.created_at
   FROM ((((public.case_participants cp
     JOIN public.participant_roles pr ON ((pr.id = cp.role_id)))
     LEFT JOIN public.persons p ON ((p.id = cp.person_id)))
     LEFT JOIN public.organizations o ON ((o.id = cp.organization_id)))
     LEFT JOIN public.case_participant_attributes cpa ON ((cpa.case_participant_id = cp.id)));


--
-- Name: VIEW v_case_participants_long_term; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_case_participants_long_term IS 'UI-friendly participant view combining person/organization party display with case-specific participant attributes.';


--
-- Name: violations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.violations (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    reference_code character varying(100),
    title character varying(255) NOT NULL,
    short_label character varying(150),
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

CREATE VIEW public.v_cases_display AS
 WITH latest_status AS (
         SELECT DISTINCT ON (h.case_id) h.case_id,
            h.to_status_id,
            cs.code AS current_status_code,
            cs.display_label AS current_status_label,
            h.status_date,
            h.changed_at
           FROM (public.case_status_history h
             JOIN public.case_statuses cs ON ((cs.id = h.to_status_id)))
          ORDER BY h.case_id, COALESCE(h.status_date, (h.changed_at)::date) DESC, h.changed_at DESC, h.id DESC
        ), active_assignment AS (
         SELECT DISTINCT ON (ca.case_id) ca.case_id,
            ca.prosecutor_id,
            p.short_name AS prosecutor_short_name,
            p.full_name AS prosecutor_full_name,
            ca.staff_id,
            st.short_name AS staff_short_name,
            st.full_name AS staff_full_name,
            ca.assigned_at
           FROM ((public.case_assignments ca
             LEFT JOIN public.prosecutors p ON ((p.id = ca.prosecutor_id)))
             LEFT JOIN public.staff st ON ((st.id = ca.staff_id)))
          WHERE (ca.unassigned_at IS NULL)
          ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
        ), court_summary AS (
         SELECT cc.case_id,
            string_agg(DISTINCT (co.code)::text, ', '::text ORDER BY (co.code)::text) AS court_codes,
            string_agg(DISTINCT NULLIF((cc.criminal_case_number)::text, ''::text), ', '::text ORDER BY NULLIF((cc.criminal_case_number)::text, ''::text)) AS criminal_case_numbers,
            bool_or(cc.needs_review) AS court_needs_review
           FROM (public.case_courts cc
             LEFT JOIN public.courts co ON ((co.id = cc.court_id)))
          GROUP BY cc.case_id
        ), violation_summary AS (
         SELECT cv.case_id,
            string_agg((v.title)::text, ', '::text ORDER BY cv.violation_order, (v.title)::text) AS violations
           FROM (public.case_violations cv
             JOIN public.violations v ON ((v.id = cv.violation_id)))
          GROUP BY cv.case_id
        )
 SELECT c.id,
    c.docket_type_id,
    c.docket_year,
    c.docket_number,
    c.date_received,
    c.source,
    c.remarks,
    c.gdrive_folder_id,
    c.gdrive_folder_link,
    c.gdrive_folder_name,
    c.gdrive_folder_status,
    c.gdrive_folder_last_scanned_at,
    c.created_by_user_id,
    c.updated_by_user_id,
    c.is_archived,
    c.created_at,
    c.updated_at,
    c.region_code,
    c.docket_month_code,
    c.legacy_source_file,
    c.legacy_source_sheet,
    c.legacy_row_number,
    c.legacy_raw_json,
    c.is_summary_procedure,
    c.summary_text,
    (((((((dt.prefix)::text || '-'::text) || (c.docket_year)::text) || '-'::text) || (COALESCE(c.docket_month_code, ''::character varying))::text) || '-'::text) || lpad((c.docket_number)::text, 6, '0'::text)) AS docket_display_number,
    dt.prefix AS docket_type_prefix,
    dt.name AS docket_type_name,
    ls.current_status_code,
    ls.current_status_label,
    ls.status_date AS current_status_date,
    aa.prosecutor_id AS current_prosecutor_id,
    aa.prosecutor_short_name,
    aa.prosecutor_full_name,
    aa.staff_id AS current_staff_id,
    aa.staff_short_name,
    aa.staff_full_name,
    aa.assigned_at AS current_assigned_at,
    court_summary.court_codes,
    court_summary.criminal_case_numbers,
    court_summary.court_needs_review,
    violation_summary.violations
   FROM (((((public.cases c
     JOIN public.docket_types dt ON ((dt.id = c.docket_type_id)))
     LEFT JOIN latest_status ls ON ((ls.case_id = c.id)))
     LEFT JOIN active_assignment aa ON ((aa.case_id = c.id)))
     LEFT JOIN court_summary ON ((court_summary.case_id = c.id)))
     LEFT JOIN violation_summary ON ((violation_summary.case_id = c.id)));


--
-- Name: v_inv2022_original_legacy_layout; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_inv2022_original_legacy_layout AS
 SELECT excel_row_number,
    region_raw AS a_region,
    docket_year_raw AS b_year,
    docket_month_raw AS c_month,
    docket_number_raw AS d_docket_number,
    complainants_raw AS e_complainants,
    complainant_age_raw AS f_complainant_age,
    complainant_gender_raw AS g_complainant_gender,
    complainant_minor_raw AS h_complainant_minor,
    'vs.'::text AS i_vs,
    respondents_raw AS j_respondents,
    respondent_age_raw AS k_respondent_age,
    respondent_gender_raw AS l_respondent_gender,
    respondent_minor_raw AS m_respondent_minor,
    violation_raw AS n_violations,
    date_received_raw AS o_date_received,
    date_raffled_raw AS p_date_raffled,
    case_classification_raw AS q_case_classification,
    minor_flag_raw AS r_minor_flag,
    senior_raw AS s_senior,
    pwd_raw AS t_pwd,
    summary_raw AS u_summary,
    prosecutor_raw AS v_prosecutor,
    date_approved_raw AS w_date_approved_out,
    status_raw AS x_status,
    date_filed_in_court_raw AS y_date_filed_in_court,
    actual_filing_date_raw AS z_actual_filing_date,
    court_raw AS aa_court,
    rtc_branch_raw AS ab_rtc_branch,
    charge_raw AS ac_charge,
    criminal_case_number_raw AS ad_criminal_case_number,
    motion_raw AS ae_motion,
    motion_date_received_raw AS af_motion_date_received,
    motion_filed_by_raw AS ag_motion_filed_by,
    motion_status_raw AS ah_motion_status,
    motion_remarks_raw AS ai_motion_remarks,
    NULL::text AS aj_days_pending,
    NULL::text AS ak_aging_60_below,
    NULL::text AS al_aging_61_120,
    NULL::text AS am_aging_121_365,
    NULL::text AS an_aging_more_than_1_year,
    NULL::text AS ao_today,
    NULL::text AS ap_days,
    remarks_mtcc_raw AS aq_remarks_mtcc,
    NULL::text AS ar_decisions_received,
    court_status_raw AS as_court_status
   FROM public.legacy_inv2022_import_rows s
  WHERE ((source_sheet = 'INV22'::text) AND (row_kind = 'VALID_DOCKET'::text));


--
-- Name: v_inv2022_original_legacy_layout_export; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_inv2022_original_legacy_layout_export AS
 SELECT a_region,
    b_year,
    c_month,
    d_docket_number,
    e_complainants,
    f_complainant_age,
    g_complainant_gender,
    h_complainant_minor,
    i_vs,
    j_respondents,
    k_respondent_age,
    l_respondent_gender,
    m_respondent_minor,
    n_violations,
    o_date_received,
    p_date_raffled,
    q_case_classification,
    r_minor_flag,
    s_senior,
    t_pwd,
    u_summary,
    v_prosecutor,
    w_date_approved_out,
    x_status,
    y_date_filed_in_court,
    z_actual_filing_date,
    aa_court,
    ab_rtc_branch,
    ac_charge,
    ad_criminal_case_number,
    ae_motion,
    af_motion_date_received,
    ag_motion_filed_by,
    ah_motion_status,
    ai_motion_remarks,
    aj_days_pending,
    ak_aging_60_below,
    al_aging_61_120,
    am_aging_121_365,
    an_aging_more_than_1_year,
    ao_today,
    ap_days,
    aq_remarks_mtcc,
    ar_decisions_received,
    as_court_status
   FROM public.v_inv2022_original_legacy_layout
  ORDER BY excel_row_number;


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
    id uuid DEFAULT gen_random_uuid() NOT NULL
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
-- Name: legacy_inq2022_import_rows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_inq2022_import_rows ALTER COLUMN id SET DEFAULT nextval('public.legacy_inq2022_import_rows_id_seq'::regclass);


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
-- Name: case_motions case_motions_case_id_source_legacy_source_file_legacy_sourc_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_motions
    ADD CONSTRAINT case_motions_case_id_source_legacy_source_file_legacy_sourc_key UNIQUE (case_id, source, legacy_source_file, legacy_source_sheet, legacy_row_number, motion_name);


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
-- Name: cases cases_gdrive_folder_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_gdrive_folder_id_key UNIQUE (gdrive_folder_id);


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
-- Name: legacy_inq2022_import_rows legacy_inq2022_import_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_inq2022_import_rows
    ADD CONSTRAINT legacy_inq2022_import_rows_pkey PRIMARY KEY (id);


--
-- Name: legacy_inv2022_import_rows legacy_inv2022_import_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_inv2022_import_rows
    ADD CONSTRAINT legacy_inv2022_import_rows_pkey PRIMARY KEY (id);


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
-- Name: legacy_inq2022_import_rows uq_legacy_inq2022_source_row; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_inq2022_import_rows
    ADD CONSTRAINT uq_legacy_inq2022_source_row UNIQUE (source_file, source_sheet, excel_row_number);


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
-- Name: violations violations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.violations
    ADD CONSTRAINT violations_pkey PRIMARY KEY (id);


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
-- Name: idx_case_assignments_case_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_assignments_case_time ON public.case_assignments USING btree (case_id, assigned_at DESC);


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
-- Name: idx_case_motions_date_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_motions_date_received ON public.case_motions USING btree (date_received DESC);


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
-- Name: idx_case_participants_legacy_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_legacy_row ON public.case_participants USING btree (legacy_source_sheet, legacy_row_number);


--
-- Name: idx_case_participants_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_organization_id ON public.case_participants USING btree (organization_id);


--
-- Name: idx_case_participants_person_case; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_participants_person_case ON public.case_participants USING btree (person_id, case_id);


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
-- Name: idx_cases_docket_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_docket_type ON public.cases USING btree (docket_type_id);


--
-- Name: idx_cases_docket_type_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_docket_type_year ON public.cases USING btree (docket_type_id, docket_year, date_received DESC);


--
-- Name: idx_cases_gdrive_folder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_gdrive_folder_id ON public.cases USING btree (gdrive_folder_id);


--
-- Name: idx_cases_gdrive_folder_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_gdrive_folder_status ON public.cases USING btree (gdrive_folder_status);


--
-- Name: idx_cases_legacy_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_legacy_source ON public.cases USING btree (legacy_source_file, legacy_source_sheet, legacy_row_number);


--
-- Name: idx_cases_region_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_region_month ON public.cases USING btree (region_code, docket_year, docket_month_code);


--
-- Name: idx_cases_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_year ON public.cases USING btree (docket_year);


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
-- Name: idx_legacy_inq2022_docket; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_inq2022_docket ON public.legacy_inq2022_import_rows USING btree (docket_year_raw, docket_month_raw, docket_number_raw);


--
-- Name: idx_legacy_inq2022_raw_json_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_inq2022_raw_json_gin ON public.legacy_inq2022_import_rows USING gin (raw_json);


--
-- Name: idx_legacy_inq2022_row_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_inq2022_row_kind ON public.legacy_inq2022_import_rows USING btree (row_kind);


--
-- Name: idx_legacy_inq2022_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_inq2022_status ON public.legacy_inq2022_import_rows USING btree (status_raw);


--
-- Name: idx_legacy_inv2022_excel_row; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_inv2022_excel_row ON public.legacy_inv2022_import_rows USING btree (excel_row_number);


--
-- Name: idx_legacy_inv2022_import_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_inv2022_import_status ON public.legacy_inv2022_import_rows USING btree (import_status);


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
-- Name: idx_persons_last_name_metaphone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_last_name_metaphone ON public.persons USING btree (public.metaphone(lower(last_name), 8));


--
-- Name: idx_persons_name_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_persons_name_lookup ON public.persons USING btree (last_name, first_name, middle_name);


--
-- Name: idx_psa_prosecutor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psa_prosecutor ON public.prosecutor_staff_assignments USING btree (prosecutor_id);


--
-- Name: idx_psa_staff; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psa_staff ON public.prosecutor_staff_assignments USING btree (staff_id);


--
-- Name: one_active_assignment_per_case; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_assignment_per_case ON public.case_assignments USING btree (case_id) WHERE (unassigned_at IS NULL);


--
-- Name: one_active_prosecutor_staff_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_prosecutor_staff_pair ON public.prosecutor_staff_assignments USING btree (prosecutor_id, staff_id) WHERE (end_date IS NULL);


--
-- Name: ux_case_participant_relationship_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_case_participant_relationship_unique ON public.case_participant_relationships USING btree (case_id, from_case_participant_id, to_case_participant_id, relationship_type);


--
-- Name: ux_case_violations_case_violation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_case_violations_case_violation ON public.case_violations USING btree (case_id, violation_id);


--
-- Name: ux_cases_gdrive_folder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_cases_gdrive_folder_id ON public.cases USING btree (gdrive_folder_id) WHERE (gdrive_folder_id IS NOT NULL);


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

CREATE UNIQUE INDEX ux_person_aliases_person_alias_lower ON public.person_aliases USING btree (person_id, lower((alias_name)::text));


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
-- Name: subscription_subscription_id_entity_filters_action_filter_key; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_key ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter);


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
-- Name: case_status_colors case_status_colors_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_status_colors
    ADD CONSTRAINT case_status_colors_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.case_statuses(id) ON DELETE CASCADE;


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
-- Name: violations violations_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.violations
    ADD CONSTRAINT violations_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.case_classifications(id);


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

\unrestrict bepKbqTd38qXfIynPDrwsWy3CTpMO9IxrS5ovkaXg9tI0asbfTqcIQyKjmF9wXM

