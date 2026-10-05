-- =============================================================================
-- Migration: 20261004020000_security_hardening_production.sql
-- Purpose:   Full Pre-Production Security Remediation & Hardening for Shabakati
-- Scope:     CRITICAL-01..04, HIGH-01..05, MEDIUM-01..06, LOW-01
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. CRITICAL-02: Fix Admin Role Metadata in auth.users & Create public.is_admin()
-- =============================================================================

-- Move admin role to trusted raw_app_meta_data and remove from user-editable raw_user_meta_data
UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb,
    raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) - 'role'
WHERE id = '4cc66948-3cc6-4f6f-a971-2dd4120e022d';

-- Ensure no other account has role in raw_app_meta_data or raw_user_meta_data
UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) - 'role',
    raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) - 'role'
WHERE id != '4cc66948-3cc6-4f6f-a971-2dd4120e022d';

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin',
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;

-- =============================================================================
-- 2. SCHEMA HARDENING: Session Tokens, Verified OTP Challenges & Column Defaults
-- =============================================================================

ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS session_token uuid,
  ADD COLUMN IF NOT EXISTS session_expires_at timestamp with time zone;

CREATE INDEX IF NOT EXISTS idx_app_users_session_token
  ON public.app_users(session_token)
  WHERE session_token IS NOT NULL;

UPDATE public.app_users
SET session_token = gen_random_uuid(),
    session_expires_at = now() + interval '30 days'
WHERE session_token IS NULL;

ALTER TABLE public.phone_otps
  ADD COLUMN IF NOT EXISTS verified_at timestamp with time zone;

CREATE TABLE IF NOT EXISTS public.verified_challenges (
  id bigserial PRIMARY KEY,
  phone text NOT NULL,
  clean_phone text NOT NULL,
  otp_id bigint REFERENCES public.phone_otps(id) ON DELETE CASCADE,
  challenge_token uuid NOT NULL DEFAULT gen_random_uuid(),
  is_consumed boolean NOT NULL DEFAULT false,
  expires_at timestamp with time zone NOT NULL,
  consumed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_verified_challenges_lookup
  ON public.verified_challenges(clean_phone, is_consumed, expires_at);

-- Fix LOW-01: Corrupted default value on orders.payment_method
ALTER TABLE public.orders
  ALTER COLUMN payment_method SET DEFAULT 'المحافظ الإلكترونية'::text;

-- =============================================================================
-- 3. CRITICAL-01: Lock Down rpc_get_backend_secrets
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_backend_secrets(p_handshake text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_result jsonb;
  v_role text;
BEGIN
  v_role := COALESCE(current_setting('request.jwt.claim.role', true), '');
  IF v_role != 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  IF p_handshake IS NULL OR encode(sha256(convert_to(p_handshake, 'UTF8')), 'hex') != '9b5368fcb23ae5912e13bfdfb514543e9141659b6317de925eafdb308d2a5d98' THEN
    RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_object_agg(key, value) INTO v_result FROM public.backend_secrets;
  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_get_backend_secrets(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_backend_secrets(text) TO service_role;

-- =============================================================================
-- 4. CRITICAL-04 & HIGH-01: OTP Creation, Verification & Password Reset Lifecycle
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rpc_create_phone_otp(
  p_phone text,
  p_clean_phone text,
  p_otp text,
  p_channel text DEFAULT 'whatsapp'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_recent_count int;
  v_role text;
  v_clean text;
BEGIN
  v_role := COALESCE(current_setting('request.jwt.claim.role', true), '');
  IF v_role != 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  v_clean := regexp_replace(COALESCE(p_clean_phone, p_phone, ''), '[^0-9]', '', 'g');

  IF p_phone IS NULL OR length(trim(p_phone)) < 7 OR length(v_clean) < 7 OR p_otp IS NULL OR length(trim(p_otp)) < 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_INPUT');
  END IF;

  -- Rate Limit: Max 3 OTPs within 3 minutes for the same phone number
  SELECT count(*) INTO v_recent_count
  FROM public.phone_otps
  WHERE (phone = trim(p_phone) OR phone = v_clean OR phone = '+' || v_clean)
    AND created_at >= (now() - interval '3 minutes');

  IF v_recent_count >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'RATE_LIMITED');
  END IF;

  -- Invalidate prior unused OTPs WITHOUT setting verified_at
  UPDATE public.phone_otps
  SET is_used = TRUE
  WHERE (phone = trim(p_phone) OR phone = v_clean OR phone = '+' || v_clean)
    AND is_used = FALSE;

  -- Invalidate any prior unconsumed verified challenges when a new OTP is requested
  UPDATE public.verified_challenges
  SET is_consumed = TRUE,
      consumed_at = now()
  WHERE (clean_phone = v_clean OR phone = trim(p_phone) OR phone = '+' || v_clean)
    AND is_consumed = FALSE;

  INSERT INTO public.phone_otps (phone, otp_code, channel, is_used, attempts, expires_at, verified_at)
  VALUES (
    trim(p_phone),
    trim(p_otp),
    COALESCE(p_channel, 'whatsapp'),
    FALSE,
    0,
    now() + interval '5 minutes',
    NULL
  );

  RETURN jsonb_build_object('success', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_create_phone_otp(text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_create_phone_otp(text, text, text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.verify_phone_otp(
  p_phone text,
  p_clean_phone text,
  p_otp text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_row public.phone_otps%ROWTYPE;
  v_clean text;
BEGIN
  IF p_otp IS NULL OR length(trim(p_otp)) < 4 THEN
    RETURN FALSE;
  END IF;

  v_clean := regexp_replace(COALESCE(p_clean_phone, p_phone, ''), '[^0-9]', '', 'g');
  IF length(v_clean) < 7 THEN
    RETURN FALSE;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('otp_' || v_clean));

  SELECT * INTO v_row
  FROM public.phone_otps
  WHERE (phone = trim(p_phone) OR phone = v_clean OR phone = ('+' || v_clean))
    AND is_used = FALSE
    AND expires_at >= now()
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  IF COALESCE(v_row.attempts, 0) >= 5 THEN
    UPDATE public.phone_otps
    SET is_used = TRUE,
        verified_at = NULL
    WHERE id = v_row.id;
    RETURN FALSE;
  END IF;

  IF v_row.otp_code != trim(p_otp) THEN
    UPDATE public.phone_otps
    SET attempts = COALESCE(attempts, 0) + 1,
        is_used = CASE WHEN COALESCE(attempts, 0) + 1 >= 5 THEN TRUE ELSE FALSE END,
        verified_at = NULL
    WHERE id = v_row.id;
    RETURN FALSE;
  END IF;

  -- Mark OTP as used AND cryptographically verified
  UPDATE public.phone_otps
  SET is_used = TRUE,
      verified_at = now()
  WHERE id = v_row.id;

  -- Consume any older unconsumed challenges for this phone
  UPDATE public.verified_challenges
  SET is_consumed = TRUE,
      consumed_at = now()
  WHERE (clean_phone = v_clean OR phone = trim(p_phone) OR phone = ('+' || v_clean))
    AND is_consumed = FALSE;

  -- Create a fresh, single-use Verified Challenge valid for 10 minutes
  INSERT INTO public.verified_challenges (
    phone, clean_phone, otp_id, challenge_token, is_consumed, expires_at
  ) VALUES (
    trim(p_phone),
    v_clean,
    v_row.id,
    gen_random_uuid(),
    FALSE,
    now() + interval '10 minutes'
  );

  -- Mark user account as verified
  UPDATE public.app_users
  SET is_verified = TRUE,
      failed_attempts = 0,
      locked_until = NULL,
      session_token = COALESCE(session_token, gen_random_uuid()),
      session_expires_at = now() + interval '30 days',
      updated_at = now()
  WHERE account_number = trim(p_phone)
     OR account_number = v_clean
     OR account_number = ('+' || v_clean);

  RETURN TRUE;
END;
$function$;

REVOKE ALL ON FUNCTION public.verify_phone_otp(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_phone_otp(text, text, text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_reset_password(
  p_account_number text,
  p_clean_phone text,
  p_new_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user public.app_users%ROWTYPE;
  v_challenge public.verified_challenges%ROWTYPE;
  v_clean text;
BEGIN
  IF p_new_hash IS NULL OR length(trim(p_new_hash)) < 32 THEN
    RETURN jsonb_build_object('error', 'INVALID_HASH');
  END IF;

  v_clean := regexp_replace(COALESCE(p_clean_phone, p_account_number, ''), '[^0-9]', '', 'g');
  IF length(v_clean) < 7 THEN
    RETURN jsonb_build_object('error', 'USER_NOT_FOUND');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('reset_' || v_clean));

  SELECT * INTO v_user
  FROM public.app_users
  WHERE account_number = trim(p_account_number)
     OR account_number = '+' || v_clean
     OR account_number = v_clean
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'USER_NOT_FOUND');
  END IF;

  -- Require an active, unconsumed, non-expired Verified Challenge linked to a genuinely verified OTP
  SELECT vc.* INTO v_challenge
  FROM public.verified_challenges vc
  JOIN public.phone_otps po ON po.id = vc.otp_id
  WHERE (
      vc.clean_phone = v_clean
      OR vc.phone = trim(p_account_number)
      OR vc.phone = '+' || v_clean
      OR vc.phone = v_user.account_number
    )
    AND vc.is_consumed = FALSE
    AND vc.expires_at >= now()
    AND po.is_used = TRUE
    AND po.verified_at IS NOT NULL
    AND po.verified_at >= (now() - interval '10 minutes')
  ORDER BY vc.created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'OTP_NOT_VERIFIED');
  END IF;

  -- Atomically consume the verified challenge so it can never be replayed
  UPDATE public.verified_challenges
  SET is_consumed = TRUE,
      consumed_at = now()
  WHERE id = v_challenge.id;

  -- Update password hash and rotate session_token
  UPDATE public.app_users
  SET password_hash = trim(p_new_hash),
      is_verified = TRUE,
      failed_attempts = 0,
      locked_until = NULL,
      session_token = gen_random_uuid(),
      session_expires_at = now() + interval '30 days',
      updated_at = now()
  WHERE id = v_user.id;

  RETURN jsonb_build_object('success', true, 'account_number', v_user.account_number);
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_reset_password(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_reset_password(text, text, text) TO anon, authenticated, service_role;

-- =============================================================================
-- 5. CRITICAL-03 & HIGH-03: Session-Authenticated Orders & Biometric RPCs
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rpc_login_user(
  p_account_number text,
  p_password_hash text,
  p_legacy_hash text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user RECORD;
  v_new_attempts INT;
  v_session_token uuid;
BEGIN
  SELECT * INTO v_user
  FROM public.app_users
  WHERE account_number = trim(p_account_number)
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'USER_NOT_FOUND');
  END IF;

  IF v_user.locked_until IS NOT NULL AND v_user.locked_until > now() THEN
    RETURN jsonb_build_object('error', 'ACCOUNT_LOCKED');
  END IF;

  IF v_user.password_hash = p_password_hash THEN
    v_session_token := gen_random_uuid();
    UPDATE public.app_users
    SET is_verified = TRUE,
        failed_attempts = 0,
        locked_until = NULL,
        session_token = v_session_token,
        session_expires_at = now() + interval '30 days',
        updated_at = now()
    WHERE id = v_user.id;

    RETURN jsonb_build_object(
      'id', v_user.id,
      'account_number', v_user.account_number,
      'dial_code', v_user.dial_code,
      'phone_national', v_user.phone_national,
      'full_name', v_user.full_name,
      'region', v_user.region,
      'is_verified', TRUE,
      'biometric_enabled', v_user.biometric_enabled,
      'created_at', v_user.created_at,
      'session_token', v_session_token
    );
  ELSIF p_legacy_hash IS NOT NULL AND v_user.password_hash = p_legacy_hash THEN
    v_session_token := gen_random_uuid();
    UPDATE public.app_users
    SET password_hash = p_password_hash,
        is_verified = TRUE,
        failed_attempts = 0,
        locked_until = NULL,
        session_token = v_session_token,
        session_expires_at = now() + interval '30 days',
        updated_at = now()
    WHERE id = v_user.id;

    RETURN jsonb_build_object(
      'id', v_user.id,
      'account_number', v_user.account_number,
      'dial_code', v_user.dial_code,
      'phone_national', v_user.phone_national,
      'full_name', v_user.full_name,
      'region', v_user.region,
      'is_verified', TRUE,
      'biometric_enabled', v_user.biometric_enabled,
      'created_at', v_user.created_at,
      'session_token', v_session_token
    );
  ELSE
    v_new_attempts := COALESCE(v_user.failed_attempts, 0) + 1;
    UPDATE public.app_users
    SET failed_attempts = v_new_attempts,
        locked_until = CASE WHEN v_new_attempts >= 5 THEN now() + interval '15 minutes' ELSE NULL END
    WHERE id = v_user.id;

    IF v_new_attempts >= 5 THEN
      RETURN jsonb_build_object('error', 'ACCOUNT_LOCKED');
    END IF;
    RETURN jsonb_build_object('error', 'INVALID_PASSWORD');
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_login_user(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_login_user(text, text, text) TO anon, authenticated, service_role;

-- Harden rpc_register_user (MEDIUM-06: race-safe lock, overwrite protection, retry limit)
CREATE OR REPLACE FUNCTION public.rpc_register_user(
  p_account_number text,
  p_dial_code text,
  p_phone_national text,
  p_full_name text,
  p_region text,
  p_password_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_existing public.app_users%ROWTYPE;
  v_user RECORD;
  v_session_token uuid;
  v_attempts int;
BEGIN
  IF p_account_number IS NULL OR length(trim(p_account_number)) < 7
     OR p_password_hash IS NULL OR length(trim(p_password_hash)) < 32 THEN
    RETURN jsonb_build_object('error', 'INVALID_INPUT');
  END IF;

  -- Transaction-scoped advisory lock to prevent concurrent registration race conditions
  PERFORM pg_advisory_xact_lock(hashtext('reg_' || trim(p_account_number)));

  SELECT * INTO v_existing
  FROM public.app_users
  WHERE account_number = trim(p_account_number)
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.is_verified = TRUE THEN
      RETURN jsonb_build_object('error', 'ACCOUNT_ALREADY_VERIFIED');
    END IF;

    IF v_existing.locked_until IS NOT NULL AND v_existing.locked_until > now() THEN
      RETURN jsonb_build_object('error', 'ACCOUNT_LOCKED');
    END IF;

    -- Prevent another user from overwriting an unverified account during active 5-minute OTP verification window
    IF v_existing.updated_at > (now() - interval '5 minutes')
       AND v_existing.password_hash IS DISTINCT FROM p_password_hash THEN
      RETURN jsonb_build_object('error', 'REGISTRATION_PENDING_VERIFICATION');
    END IF;

    v_attempts := COALESCE(v_existing.failed_attempts, 0) + 1;
    IF v_attempts > 5 THEN
      UPDATE public.app_users
      SET locked_until = now() + interval '15 minutes'
      WHERE id = v_existing.id;
      RETURN jsonb_build_object('error', 'ACCOUNT_LOCKED');
    END IF;

    v_session_token := gen_random_uuid();

    UPDATE public.app_users
    SET full_name = trim(p_full_name),
        region = COALESCE(p_region, 'A'),
        password_hash = p_password_hash,
        failed_attempts = v_attempts,
        session_token = v_session_token,
        session_expires_at = now() + interval '30 days',
        updated_at = now()
    WHERE id = v_existing.id
    RETURNING id, account_number, dial_code, phone_national, full_name, region, is_verified, biometric_enabled, created_at, session_token
    INTO v_user;

    RETURN to_jsonb(v_user);
  END IF;

  v_session_token := gen_random_uuid();

  INSERT INTO public.app_users (
    account_number, dial_code, phone_national, full_name, region, password_hash,
    is_verified, biometric_enabled, failed_attempts, session_token, session_expires_at
  )
  VALUES (
    trim(p_account_number),
    COALESCE(p_dial_code, '+967'),
    trim(p_phone_national),
    trim(p_full_name),
    COALESCE(p_region, 'A'),
    p_password_hash,
    FALSE,
    FALSE,
    1,
    v_session_token,
    now() + interval '30 days'
  )
  RETURNING id, account_number, dial_code, phone_national, full_name, region, is_verified, biometric_enabled, created_at, session_token
  INTO v_user;

  RETURN to_jsonb(v_user);
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_register_user(text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_register_user(text, text, text, text, text, text) TO anon, authenticated, service_role;

-- Replace rpc_get_user_orders to close CRITICAL-03 (IDOR/BOLA)
DROP FUNCTION IF EXISTS public.rpc_get_user_orders(text, text, bigint);

CREATE OR REPLACE FUNCTION public.rpc_get_user_orders(
  p_account_number text DEFAULT NULL::text,
  p_phone_national text DEFAULT NULL::text,
  p_user_id bigint DEFAULT NULL::bigint,
  p_session_token uuid DEFAULT NULL::uuid
)
RETURNS SETOF public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user public.app_users%ROWTYPE;
  v_clean_acc text;
  v_clean_nat text;
BEGIN
  -- 1. Require a valid server-issued session_token (unless caller is admin or service_role)
  IF p_session_token IS NULL THEN
    IF NOT public.is_admin() AND COALESCE(current_setting('request.jwt.claim.role', true), '') != 'service_role' THEN
      RAISE EXCEPTION 'UNAUTHORIZED: valid session_token is required' USING ERRCODE = '42501';
    END IF;
  END IF;

  v_clean_acc := trim(COALESCE(p_account_number, ''));
  v_clean_nat := trim(COALESCE(p_phone_national, ''));

  IF p_session_token IS NOT NULL THEN
    SELECT * INTO v_user
    FROM public.app_users
    WHERE session_token = p_session_token
      AND (session_expires_at IS NULL OR session_expires_at > now())
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'UNAUTHORIZED: invalid or expired session_token' USING ERRCODE = '42501';
    END IF;

    -- Prevent BOLA/IDOR: if caller also passed account_number, user_id, or phone_national, they MUST match v_user
    IF (v_clean_acc != '' AND v_clean_acc != v_user.account_number)
       OR (p_user_id IS NOT NULL AND p_user_id != v_user.id)
       OR (v_clean_nat != '' AND v_clean_nat != v_user.phone_national) THEN
      RAISE EXCEPTION 'FORBIDDEN: ownership mismatch' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT *
    FROM public.orders o
    WHERE o.user_id = v_user.id
       OR o.account_number = v_user.account_number
       OR o.contact_phone = v_user.account_number
       OR (v_user.phone_national IS NOT NULL AND length(v_user.phone_national) >= 7
           AND (o.account_number = v_user.phone_national OR o.contact_phone = v_user.phone_national))
    ORDER BY o.created_at DESC;
    RETURN;
  END IF;

  -- Admin / service_role fallback
  RETURN QUERY
  SELECT *
  FROM public.orders o
  WHERE (p_user_id IS NOT NULL AND o.user_id = p_user_id)
     OR (v_clean_acc != '' AND (o.account_number = v_clean_acc OR o.contact_phone = v_clean_acc))
  ORDER BY o.created_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_get_user_orders(text, text, bigint, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_user_orders(text, text, bigint, uuid) TO anon, authenticated, service_role;

-- Replace rpc_update_biometric to close HIGH-03 ownership gap
DROP FUNCTION IF EXISTS public.rpc_update_biometric(text, boolean);

CREATE OR REPLACE FUNCTION public.rpc_update_biometric(
  p_account_number text,
  p_enabled boolean,
  p_session_token uuid DEFAULT NULL::uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  IF p_session_token IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: valid session_token is required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.app_users
  SET biometric_enabled = p_enabled,
      updated_at = now()
  WHERE account_number = trim(p_account_number)
    AND session_token = p_session_token
    AND (session_expires_at IS NULL OR session_expires_at > now());

  IF NOT FOUND THEN
    RAISE EXCEPTION 'FORBIDDEN: invalid session or ownership mismatch' USING ERRCODE = '42501';
  END IF;

  RETURN TRUE;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_update_biometric(text, boolean, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_update_biometric(text, boolean, uuid) TO anon, authenticated, service_role;

-- Harden rpc_change_password & rpc_check_account_exists & rls_auto_enable (MEDIUM-01 & MEDIUM-04)
CREATE OR REPLACE FUNCTION public.rpc_change_password(
  p_account_number text,
  p_old_hash text,
  p_old_legacy_hash text,
  p_new_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user public.app_users%ROWTYPE;
  v_new_attempts INT;
BEGIN
  SELECT * INTO v_user
  FROM public.app_users
  WHERE account_number = trim(p_account_number)
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'USER_NOT_FOUND');
  END IF;

  IF v_user.locked_until IS NOT NULL AND v_user.locked_until > now() THEN
    RETURN jsonb_build_object('error', 'ACCOUNT_LOCKED');
  END IF;

  IF v_user.password_hash != p_old_hash AND (p_old_legacy_hash IS NULL OR v_user.password_hash != p_old_legacy_hash) THEN
    v_new_attempts := COALESCE(v_user.failed_attempts, 0) + 1;
    UPDATE public.app_users
    SET failed_attempts = v_new_attempts,
        locked_until = CASE WHEN v_new_attempts >= 5 THEN now() + interval '15 minutes' ELSE NULL END
    WHERE id = v_user.id;

    IF v_new_attempts >= 5 THEN
      RETURN jsonb_build_object('error', 'ACCOUNT_LOCKED');
    END IF;
    RETURN jsonb_build_object('error', 'INVALID_OLD_PASSWORD');
  END IF;

  UPDATE public.app_users
  SET password_hash = p_new_hash,
      failed_attempts = 0,
      locked_until = NULL,
      updated_at = now()
  WHERE id = v_user.id;

  RETURN jsonb_build_object('success', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_change_password(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_change_password(text, text, text, text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_check_account_exists(p_account_number text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user public.app_users%ROWTYPE;
  v_clean TEXT;
  v_nat TEXT;
BEGIN
  v_clean := regexp_replace(COALESCE(p_account_number, ''), '[^0-9]', '', 'g');
  IF length(v_clean) < 7 THEN
    RETURN jsonb_build_object('exists', false);
  END IF;

  IF v_clean LIKE '9670%' AND length(v_clean) = 13 THEN
    v_clean := '967' || substring(v_clean FROM 5);
  ELSIF v_clean LIKE '0%' AND length(v_clean) = 10 THEN
    v_clean := '967' || substring(v_clean FROM 2);
  ELSIF v_clean NOT LIKE '967%' AND length(v_clean) = 9 THEN
    v_clean := '967' || v_clean;
  END IF;

  v_nat := CASE WHEN v_clean LIKE '967%' THEN substring(v_clean FROM 4) ELSE v_clean END;

  SELECT * INTO v_user
  FROM public.app_users
  WHERE account_number = trim(p_account_number)
     OR account_number = '+' || v_clean
     OR account_number = v_clean
     OR (length(v_nat) >= 7 AND phone_national = v_nat)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('exists', false);
  END IF;

  RETURN jsonb_build_object(
    'exists', true,
    'account_number', v_user.account_number
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_check_account_exists(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_check_account_exists(text) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;

-- =============================================================================
-- 6. CRITICAL-02, HIGH-02, HIGH-05, MEDIUM-02: RLS & FORCE RLS Across All Tables
-- =============================================================================

-- Enable & Force RLS on every table in public
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings FORCE ROW LEVEL SECURITY;

ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_users FORCE ROW LEVEL SECURITY;

ALTER TABLE public.backend_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backend_secrets FORCE ROW LEVEL SECURITY;

ALTER TABLE public.cached_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cached_products FORCE ROW LEVEL SECURITY;

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories FORCE ROW LEVEL SECURITY;

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items FORCE ROW LEVEL SECURITY;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders FORCE ROW LEVEL SECURITY;

ALTER TABLE public.payment_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_logs FORCE ROW LEVEL SECURITY;

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments FORCE ROW LEVEL SECURITY;

ALTER TABLE public.phone_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.phone_otps FORCE ROW LEVEL SECURITY;

ALTER TABLE public.product_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_settings FORCE ROW LEVEL SECURITY;

ALTER TABLE public.verified_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verified_challenges FORCE ROW LEVEL SECURITY;

-- Drop old permissive/broken policies
DROP POLICY IF EXISTS "Admin manage app_settings" ON public.app_settings;
DROP POLICY IF EXISTS "Public read app_settings" ON public.app_settings;

DROP POLICY IF EXISTS "Admin read app_users" ON public.app_users;

DROP POLICY IF EXISTS "Public read cached_products" ON public.cached_products;
DROP POLICY IF EXISTS "Admin manage cached_products" ON public.cached_products;

DROP POLICY IF EXISTS "Public read categories" ON public.categories;
DROP POLICY IF EXISTS "Admin manage categories" ON public.categories;

DROP POLICY IF EXISTS "Allow anonymous insert order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow anonymous read order_items" ON public.order_items;
DROP POLICY IF EXISTS "Public insert order_items" ON public.order_items;
DROP POLICY IF EXISTS "Public read order_items" ON public.order_items;
DROP POLICY IF EXISTS "Admin manage order_items" ON public.order_items;

DROP POLICY IF EXISTS "Admin manage orders" ON public.orders;

DROP POLICY IF EXISTS "Admin read payment_logs" ON public.payment_logs;

DROP POLICY IF EXISTS "Admin read payments" ON public.payments;

DROP POLICY IF EXISTS "Admin manage product_settings" ON public.product_settings;
DROP POLICY IF EXISTS "Public read product_settings" ON public.product_settings;

-- Recreate strict RLS policies using public.is_admin()

-- app_settings: Public SELECT, Admin ALL
CREATE POLICY "Public read app_settings"
  ON public.app_settings FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Admin manage app_settings"
  ON public.app_settings FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- product_settings: Public SELECT, Admin ALL
CREATE POLICY "Public read product_settings"
  ON public.product_settings FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Admin manage product_settings"
  ON public.product_settings FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- categories: Public SELECT active, Admin ALL
CREATE POLICY "Public read categories"
  ON public.categories FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

CREATE POLICY "Admin manage categories"
  ON public.categories FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- cached_products: Public SELECT, Admin ALL
CREATE POLICY "Public read cached_products"
  ON public.cached_products FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Admin manage cached_products"
  ON public.cached_products FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- orders: Admin ONLY (Customers access only via session-verified RPC, Backend via service_role)
CREATE POLICY "Admin manage orders"
  ON public.orders FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- order_items: Admin ONLY (Backend inserts via service_role)
CREATE POLICY "Admin manage order_items"
  ON public.order_items FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- payments: Admin SELECT ONLY
CREATE POLICY "Admin read payments"
  ON public.payments FOR SELECT
  TO authenticated
  USING (public.is_admin());

-- payment_logs: Admin SELECT ONLY
CREATE POLICY "Admin read payment_logs"
  ON public.payment_logs FOR SELECT
  TO authenticated
  USING (public.is_admin());

-- app_users: Admin SELECT ONLY
CREATE POLICY "Admin read app_users"
  ON public.app_users FOR SELECT
  TO authenticated
  USING (public.is_admin());

-- phone_otps, verified_challenges, backend_secrets: NO policies for anon/authenticated (Deny All)

-- =============================================================================
-- 7. HIGH-03 & HIGH-04: Enforce Strict Least Privilege on Tables & Sequences
-- =============================================================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;

-- Grant read-only access on public catalog/configuration tables to anon
GRANT SELECT ON public.app_settings TO anon;
GRANT SELECT ON public.product_settings TO anon;
GRANT SELECT ON public.categories TO anon;
GRANT SELECT ON public.cached_products TO anon;

-- Grant strictly scoped privileges to authenticated (further gated by public.is_admin() RLS)
GRANT SELECT, INSERT, UPDATE ON public.app_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.product_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.categories TO authenticated;
GRANT SELECT ON public.cached_products TO authenticated;
GRANT SELECT, UPDATE ON public.orders TO authenticated;
GRANT SELECT ON public.order_items TO authenticated;
GRANT SELECT ON public.payments TO authenticated;
GRANT SELECT ON public.payment_logs TO authenticated;
GRANT SELECT ON public.app_users TO authenticated;

-- Ensure service_role retains full access
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- =============================================================================
-- 8. MEDIUM-03: Storage Security (service-icons bucket & storage.objects RLS)
-- =============================================================================

UPDATE storage.buckets
SET public = true,
    file_size_limit = 2097152, -- 2 MB
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp']
WHERE id = 'service-icons';

DROP POLICY IF EXISTS "Public read service-icons" ON storage.objects;
DROP POLICY IF EXISTS "Admin manage service-icons" ON storage.objects;

CREATE POLICY "Public read service-icons"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'service-icons');

CREATE POLICY "Admin manage service-icons"
  ON storage.objects FOR ALL
  TO authenticated
  USING (bucket_id = 'service-icons' AND public.is_admin())
  WITH CHECK (bucket_id = 'service-icons' AND public.is_admin());

-- =============================================================================
-- 9. MEDIUM-05: Remove sensitive public.orders from Realtime publication
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.orders;
  END IF;
END
$$;

COMMIT;
