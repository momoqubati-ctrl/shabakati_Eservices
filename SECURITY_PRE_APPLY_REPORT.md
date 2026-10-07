# SECURITY PRE-APPLY REPORT — Shabakati / شبكتي

**Date:** 2026-10-04  
**Migration File:** `supabase/migrations/20261004020000_security_hardening_production.sql`

---

## 1. Current State & Affected Objects

| Object Type | Affected Objects | Current State |
|-------------|------------------|---------------|
| **Auth Users** | `auth.users` (`4cc66948-3cc6-4f6f-a971-2dd4120e022d`) | `role` stored in `raw_user_meta_data` instead of `raw_app_meta_data` |
| **Tables** | `app_settings`, `app_users`, `backend_secrets`, `cached_products`, `categories`, `order_items`, `orders`, `payment_logs`, `payments`, `phone_otps`, `product_settings`, `verified_challenges` (new) | `relforcerowsecurity = false`; excessive `anon`/`authenticated` grants (`arwdDxtm`); corrupted default on `orders.payment_method` |
| **Policies** | All policies on `public.*` and `storage.objects` | Admin policies use `USING (true)` for any `authenticated` user; `order_items` has 4 `PUBLIC` read/insert policies |
| **Functions** | `is_admin` (new), `rls_auto_enable`, `rpc_change_password`, `rpc_check_account_exists`, `rpc_create_phone_otp`, `rpc_get_backend_secrets`, `rpc_get_user_orders`, `rpc_login_user`, `rpc_register_user`, `rpc_reset_password`, `rpc_update_biometric`, `verify_phone_otp` | Missing `pg_temp` in `search_path`; `rpc_get_backend_secrets` and `rpc_create_phone_otp` executable by `anon`; `rpc_get_user_orders` and `rpc_update_biometric` lack session token verification; `rpc_reset_password` checks `is_used = true` |
| **Storage** | `storage.buckets` (`service-icons`), `storage.objects` | `file_size_limit = null`, `allowed_mime_types = null`, missing `storage.objects` RLS policies |
| **Realtime** | `supabase_realtime` publication | Publishes `public.orders` |

---

## 2. Dependencies Analysis

1. **`rpc_get_backend_secrets`**:
   - **Consumers**: `api/orders.js`, `api/send-otp.js`, `api/basgate-initiate.js`, `api/basgate-verify.js`, `api/basgate-webhook.js`, `api/catalog.js`.
   - **Impact**: All 6 serverless functions prioritize `process.env.*` variables and only use `getServerSecrets()` as a fallback. By restricting `rpc_get_backend_secrets` to `service_role` and updating `getServerSecrets()` to authenticate with `SUPABASE_SERVICE_ROLE_KEY` and `process.env.SERVER_HANDSHAKE_KEY`, public access is completely blocked without breaking backend execution.
2. **`public.is_admin()` & Admin Policies**:
   - **Consumers**: `admin_dashboard` (`App.jsx`, `OrderDetailModal.jsx`, `CatalogManagement.jsx`) and `api/_lib/adminAuth.js`.
   - **Impact**: `App.jsx` (line 16) and `adminAuth.js` (line 19) already check `user?.app_metadata?.role === 'admin'`. Moving the admin role to `raw_app_meta_data` fixes admin authentication while blocking non-admin `authenticated` users.
3. **`rpc_get_user_orders` & `rpc_update_biometric`**:
   - **Consumers**: Flutter `OrderRepository.getOrdersForUser` and `AuthRepository.updateBiometricStatus`.
   - **Impact**: Adding `session_token` to `app_users` and returning it from `rpc_login_user`, `rpc_register_user`, and `verify_phone_otp` allows the Flutter client to pass `p_session_token` on every call. Unauthenticated or mismatched calls receive `HTTP 403` (`42501`).
4. **`rpc_create_phone_otp`, `verify_phone_otp`, `rpc_reset_password`**:
   - **Consumers**: `api/send-otp.js` calls `rpc_create_phone_otp` using `SUPABASE_SERVICE_ROLE_KEY`; Flutter `OtpService.verifyOtp` calls `verify_phone_otp`; Flutter `AuthRepository.resetPassword` calls `rpc_reset_password`.
   - **Impact**: Function signatures for `verify_phone_otp` and `rpc_reset_password` remain unchanged, while the internal verification uses `public.verified_challenges` to prevent OTP replay and premature `is_used = true` exploitation.

---

## 3. Rollback Strategy

The migration is wrapped in an atomic transaction (`BEGIN; ... COMMIT;`). If any statement fails, PostgreSQL rolls back the entire transaction automatically. To revert post-application:
- Restore previous policy definitions and function bodies from git commit `fe85dac` / database snapshot.
- Drop `public.verified_challenges` and `app_users.session_token` if needed.

---

## 4. Expected Behavior & Test Plan

1. `anon` calling `rpc_get_backend_secrets` or `rpc_create_phone_otp` -> **HTTP 401/403 DENIED**.
2. `anon` or normal `authenticated` user querying `orders`, `order_items`, `payments`, `payment_logs`, `app_users` -> **DENIED (0 rows / HTTP 403)**.
3. `admin` (`app_metadata.role = 'admin'`) querying `orders`, `order_items`, `payments`, `payment_logs`, `app_users`, `app_settings`, `product_settings` -> **ALLOW**.
4. `rpc_get_user_orders` without valid matching `p_session_token` or with another user's `account_number`/`user_id` -> **HTTP 403 DENIED**.
5. Password reset without verified challenge, after wrong OTP, after 2nd OTP request, or on replay -> **DENIED (`OTP_NOT_VERIFIED`)**.
6. Storage upload to `service-icons` with `.html`, `.svg`, or `>2MB`, or by non-admin -> **DENIED**.
