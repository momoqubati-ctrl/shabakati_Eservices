# SECURITY REMEDIATION PLAN — Shabakati / شبكتي

**Date:** 2026-10-04  
**Initial Gate Status:** `NOT READY FOR PRODUCTION`  
**Target Gate Status:** `READY FOR PRODUCTION` (Evidence-Verified)

---

## 1. Findings Verification & Classification (Evidence-First)

| ID | Severity | Finding | Classification | Pre-Fix Evidence |
|----|----------|---------|----------------|------------------|
| **CRITICAL-01** | CRITICAL | `rpc_get_backend_secrets` executable by `anon`, `authenticated`, `PUBLIC` with hardcoded handshake in `api/*.js` | **CONFIRMED** | `POST /rest/v1/rpc/rpc_get_backend_secrets` with `anon` JWT returned HTTP 200 and all 11 secret keys; ACL had `{=X,anon=X,authenticated=X}` |
| **CRITICAL-02** | CRITICAL | Admin authorization relies on `USING (true)` for `authenticated`, and admin role is in `raw_user_meta_data` instead of `raw_app_meta_data` | **CONFIRMED** | `auth.users` row `4cc66948-3cc6-4f6f-a971-2dd4120e022d` has `raw_app_meta_data={"provider":"email","providers":["email"]}` (no `role`), while `raw_user_meta_data` has `"role":"super_admin"`. All admin policies on `orders`, `payments`, `payment_logs`, `app_users`, `app_settings`, `product_settings` use `TO authenticated USING (true)` |
| **CRITICAL-03** | CRITICAL | `rpc_get_user_orders` vulnerable to IDOR/BOLA — accepts arbitrary `p_account_number`, `p_phone_national`, `p_user_id` without server-side session ownership verification | **CONFIRMED** | `POST /rest/v1/rpc/rpc_get_user_orders` with `anon` JWT and any account number returns HTTP 200 without ownership proof |
| **CRITICAL-04** | CRITICAL | `rpc_create_phone_otp` executable by `anon`, `authenticated`, `PUBLIC` — allows attacker to inject custom known OTP codes | **CONFIRMED** | `POST /rest/v1/rpc/rpc_create_phone_otp` with `anon` JWT and `p_otp="1234"` returned HTTP 200 `{"success": true}` |
| **HIGH-01** | HIGH | OTP & Password Reset lifecycle flaw — `rpc_reset_password` checks `is_used = true` instead of a verified challenge, allowing password reset after requesting a 2nd OTP or exhausting 5 wrong attempts | **CONFIRMED** | `rpc_create_phone_otp` sets `is_used = TRUE` on prior OTPs; 5 failed attempts in `verify_phone_otp` set `is_used = TRUE`; `rpc_reset_password` checks `WHERE is_used = true` |
| **HIGH-02** | HIGH | `order_items` exposed via 4 permissive `PUBLIC` policies (`SELECT USING(true)`, `INSERT WITH CHECK(true)`) and lacks an Admin policy | **CONFIRMED** | `GET /rest/v1/order_items?limit=5` with `anon` JWT returned HTTP 200 with 5 order item rows |
| **HIGH-03** | HIGH | Least Privilege violation — `anon` and `authenticated` hold `INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER` (`arwdDxtm`) on financial and sensitive tables & sequences; `rpc_update_biometric` lacks ownership check | **CONFIRMED** | `pg_class.relacl` shows `anon=arwdDxtm` on `payments`, `payment_logs`, `order_items`, `app_users`; `rpc_update_biometric` updates `app_users` by `p_account_number` alone |
| **MEDIUM-01** | MEDIUM | `SECURITY DEFINER` functions in `public` use `SET search_path TO 'public'` without `pg_temp` | **CONFIRMED** | All 10 RPCs in `public` lack `pg_temp` in `search_path` |
| **MEDIUM-02** | MEDIUM | `FORCE ROW LEVEL SECURITY` (`relforcerowsecurity`) is `false` on all 11 tables in `public` | **CONFIRMED** | `pg_class.relforcerowsecurity = false` across all tables |
| **MEDIUM-03** | MEDIUM | Storage bucket `service-icons` has `file_size_limit = NULL` and `allowed_mime_types = NULL` (allows HTML/SVG/oversized files) and lacks strict admin write RLS on `storage.objects` | **CONFIRMED** | `storage.buckets` shows `('service-icons', 'service-icons', True, None, None)` |
| **MEDIUM-04** | MEDIUM | `rls_auto_enable()` event trigger function grants `EXECUTE` to `PUBLIC`, `anon`, `authenticated` | **CONFIRMED** | `proacl` shows `{=X,anon=X,authenticated=X}` |
| **MEDIUM-05** | MEDIUM | `public.orders` is included in `supabase_realtime` publication | **CONFIRMED** | `pg_publication_tables` includes `('supabase_realtime', 'public', 'orders')` |
| **MEDIUM-06** | MEDIUM | `rpc_register_user` lacks row locking (`FOR UPDATE`/advisory lock) and allows immediate overwrite of unverified accounts within the active OTP verification window | **CONFIRMED** | Function definition overwrites `full_name`, `region`, `password_hash` whenever `is_verified = FALSE` without cooldown or lock |
| **LOW-01** | LOW | `orders.payment_method` default value contains corrupted encoding `'??????? ???????????'::text` | **CONFIRMED** | `information_schema.columns` shows `'??????? ???????????'::text` |

---

## 2. Phased Execution Plan

### PHASE 1 — CRITICAL
1. **CRITICAL-01 (`rpc_get_backend_secrets`)**:
   - Revoke `EXECUTE` on `public.rpc_get_backend_secrets(text)` from `PUBLIC`, `anon`, and `authenticated`. Grant `EXECUTE` only to `service_role`.
   - Enforce `service_role` caller check inside `rpc_get_backend_secrets`.
   - Remove hardcoded handshake fallback from `api/orders.js`, `api/send-otp.js`, `api/basgate-initiate.js`, `api/basgate-verify.js`, `api/basgate-webhook.js`, and `api/catalog.js`.
2. **CRITICAL-02 (`public.is_admin()` & Admin Metadata)**:
   - Update `auth.users` for `4cc66948-3cc6-4f6f-a971-2dd4120e022d` (`admin@shabakti.com`): set `raw_app_meta_data` to include `"role": "admin"` and strip `"role"` from `raw_user_meta_data`.
   - Create `public.is_admin()` checking `(auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'`.
   - Replace all `USING (true)` admin policies on `orders`, `order_items`, `payments`, `payment_logs`, `app_users`, `app_settings`, `product_settings`, `categories`, `cached_products` with `USING (public.is_admin()) WITH CHECK (public.is_admin())`.
3. **CRITICAL-03 (`rpc_get_user_orders` IDOR/BOLA)**:
   - Add `session_token uuid` and `session_expires_at timestamptz` columns to `public.app_users`.
   - Issue/rotate `session_token` upon `rpc_login_user`, `rpc_register_user`, and `verify_phone_otp`.
   - Require valid `p_session_token` in `rpc_get_user_orders` that matches the authenticated user's row in `public.app_users`, querying orders strictly by the verified user record (`v_user.id`, `v_user.account_number`, `v_user.phone_national`) and raising `42501` (`INSUFFICIENT PRIVILEGE` / HTTP 403) on any mismatch or missing token.
   - Update Flutter `UserAccountModel`, `SecureStorageService`, `AuthRepository`, `AuthCubit`, and `OrderRepository` to persist and send `session_token`.
4. **CRITICAL-04 (`rpc_create_phone_otp`)**:
   - Revoke `EXECUTE` on `public.rpc_create_phone_otp(text, text, text, text)` from `PUBLIC`, `anon`, and `authenticated`. Grant `EXECUTE` only to `service_role`.

### PHASE 2 — HIGH
1. **HIGH-01 (OTP & Password Reset Lifecycle)**:
   - Create `public.verified_challenges` table (RLS enabled & forced, accessible only by `service_role` and `SECURITY DEFINER` functions) and add `verified_at timestamptz` to `public.phone_otps`.
   - `verify_phone_otp` records `verified_at = now()` and creates a short-lived (10-minute), single-use row in `public.verified_challenges` ONLY when the submitted OTP matches.
   - `rpc_create_phone_otp` invalidates any unconsumed challenges for the phone number when a new OTP is requested.
   - `rpc_reset_password` requires an unconsumed, non-expired row in `public.verified_challenges`, atomically marks it `is_consumed = true`, updates the password hash, and rotates `session_token`.
2. **HIGH-02 (`order_items` lockdown)**:
   - Drop all 4 public policies on `public.order_items`.
   - Add `"Admin manage order_items"` policy restricted to `public.is_admin()`.
3. **HIGH-03 (Least Privilege & `rpc_update_biometric`)**:
   - Revoke all unnecessary table and sequence privileges from `PUBLIC`, `anon`, and `authenticated`.
   - Grant only `SELECT` on public catalog tables (`app_settings`, `product_settings`, `categories`, `cached_products`) to `anon`.
   - Grant only minimum required operations to `authenticated` (gated by `public.is_admin()` RLS).
   - Require valid `p_session_token` in `rpc_update_biometric`.

### PHASE 3 — MEDIUM & PHASE 4 — LOW
1. **MEDIUM-01**: Set `search_path = public, pg_temp` on all `SECURITY DEFINER` functions in `public`.
2. **MEDIUM-02**: Enable `FORCE ROW LEVEL SECURITY` on all tables in `public`.
3. **MEDIUM-03**: Configure `storage.buckets` (`service-icons`) with `file_size_limit = 2097152` (2MB) and `allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp']`, and enforce admin-only write policies on `storage.objects`.
4. **MEDIUM-04**: Revoke `EXECUTE` on `public.rls_auto_enable()` from `PUBLIC`, `anon`, and `authenticated`.
5. **MEDIUM-05**: Remove `public.orders` from `supabase_realtime` publication.
6. **MEDIUM-06**: Harden `rpc_register_user` with transaction-level advisory lock, row lock (`FOR UPDATE`), and a 5-minute verification window protection against unauthorized overwrite.
7. **LOW-01**: Fix `orders.payment_method` column default to `'المحافظ الإلكترونية'::text`.

### PHASE 5 — REGRESSION & PHASE 6 — PRODUCTION SECURITY GATE
- Execute full automated security regression suite (`security_audit/01_anon_access.py` through `13_sensitive_data_exposure.py`) using real PostgREST HTTP requests and real JWTs (`anon`, normal `authenticated`, `admin`, and `service_role`).
- Generate final evidence deliverables (`SECURITY_REMEDIATION_REPORT.md`, `SECURITY_FINDINGS_BEFORE_AFTER.md`, `SECURITY_TEST_RESULTS.md`, `PRODUCTION_SECURITY_GATE.json`).
