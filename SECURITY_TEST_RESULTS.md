# SECURITY TEST RESULTS — Shabakati / شبكتي

**Execution Timestamp:** 2026-10-04  
**Test Runner:** [`security_audit/run_all_audits.py`](file:///d:/shabakti_Eservices/security_audit/run_all_audits.py)  
**Methodology:** Live PostgREST HTTP requests + Real GoTrue JWTs (`anon`, normal `authenticated`, `admin`, `service_role`) + Supabase Storage REST API + Catalog/ACL Introspection + Source Code Static Scan.

---

## 1. Summary

| Metric | Value |
|--------|-------|
| **Total Security & Regression Tests** | **78** |
| **Passed (`PASS`)** | **78** |
| **Failed (`FAIL`)** | **0** |
| **Not Tested (`NOT_TESTED`)** | **0** |
| **Node.js Backend Unit Tests (`api/_lib/*.test.js`)** | **7 / 7 PASS** |
| **Flutter Static Analysis (`flutter analyze`)** | **0 Issues** |

---

## 2. Authorization Matrix Verification (Live PostgREST + Real GoTrue JWT)

| Resource / Operation | `anon` JWT | Normal `authenticated` JWT (`role != admin`) | `admin` JWT (`app_metadata.role = admin`) | `service_role` | Result |
|----------------------|------------|----------------------------------------------|-------------------------------------------|----------------|--------|
| `orders` (SELECT / WRITE) | DENY (HTTP 401) | DENY (0 rows / HTTP 403) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `order_items` (SELECT / INSERT) | DENY (HTTP 401) | DENY (0 rows / HTTP 403) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `payments` (SELECT / WRITE) | DENY (HTTP 401) | DENY (0 rows / HTTP 403) | ALLOW SELECT (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `payment_logs` (SELECT / WRITE) | DENY (HTTP 401) | DENY (0 rows / HTTP 403) | ALLOW SELECT (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `app_users` (SELECT / WRITE) | DENY (HTTP 401) | DENY (0 rows / HTTP 403) | ALLOW SELECT (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `app_settings` (SELECT) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `app_settings` (WRITE) | DENY (HTTP 401) | DENY (HTTP 403) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `product_settings` (SELECT) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `product_settings` (WRITE) | DENY (HTTP 401) | DENY (HTTP 403) | ALLOW (HTTP 200) | ALLOW (HTTP 200) | **PASS** |
| `backend_secrets` (SELECT) | DENY (HTTP 401) | DENY (HTTP 403) | DENY (HTTP 403) | ALLOW (HTTP 200) | **PASS** |
| `phone_otps` (SELECT) | DENY (HTTP 401) | DENY (HTTP 403) | DENY (HTTP 403) | ALLOW (HTTP 200) | **PASS** |
| `verified_challenges` (SELECT) | DENY (HTTP 401) | DENY (HTTP 403) | DENY (HTTP 403) | ALLOW (HTTP 200) | **PASS** |

---

## 3. Detailed Test Suite Results (`01` – `13`)

### Suite `00_jwt_setup`
- `[PASS]` Real GoTrue JWT acquired for normal authenticated user (`364ab8b2-26f5-41d0-b615-f52569d35a8c`)
- `[PASS]` Real GoTrue JWT acquired for admin user (`4cc66948-3cc6-4f6f-a971-2dd4120e022d`)

### Suite `01_anon_access`
- `[PASS]` `anon` SELECT on `orders` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `order_items` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `payments` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `payment_logs` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `app_users` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `phone_otps` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `backend_secrets` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `verified_challenges` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `app_settings` is ALLOWED (`HTTP 200`)
- `[PASS]` `anon` WRITE on `app_settings` is DENIED (`HTTP 401`)
- `[PASS]` `anon` SELECT on `product_settings` is ALLOWED (`HTTP 200`)
- `[PASS]` `anon` WRITE on `product_settings` is DENIED (`HTTP 401`)

### Suite `02_authenticated_access`
- `[PASS]` Normal `authenticated` SELECT on `orders` returns 0 rows / DENIED (`HTTP 200, rows=0`)
- `[PASS]` Normal `authenticated` SELECT on `order_items` returns 0 rows / DENIED (`HTTP 200, rows=0`)
- `[PASS]` Normal `authenticated` SELECT on `payments` returns 0 rows / DENIED (`HTTP 200, rows=0`)
- `[PASS]` Normal `authenticated` SELECT on `payment_logs` returns 0 rows / DENIED (`HTTP 200, rows=0`)
- `[PASS]` Normal `authenticated` SELECT on `app_users` returns 0 rows / DENIED (`HTTP 200, rows=0`)
- `[PASS]` Normal `authenticated` WRITE on `app_settings` is DENIED (`HTTP 403`)
- `[PASS]` Normal `authenticated` WRITE on `product_settings` is DENIED (`HTTP 403`)

### Suite `03_admin_access`
- `[PASS]` `admin` SELECT on `orders` is ALLOWED (`HTTP 200`)
- `[PASS]` `admin` SELECT on `order_items` is ALLOWED (`HTTP 200`)
- `[PASS]` `admin` SELECT on `payments` is ALLOWED (`HTTP 200`)
- `[PASS]` `admin` SELECT on `payment_logs` is ALLOWED (`HTTP 200`)
- `[PASS]` `admin` SELECT on `app_users` is ALLOWED (`HTTP 200`)
- `[PASS]` `admin` SELECT on `app_settings` is ALLOWED (`HTTP 200`)
- `[PASS]` `admin` SELECT on `product_settings` is ALLOWED (`HTTP 200`)
- `[PASS]` `admin` direct SELECT on `backend_secrets` is DENIED (`HTTP 403`)
- `[PASS]` `admin` direct SELECT on `phone_otps` is DENIED (`HTTP 403`)
- `[PASS]` `admin` direct SELECT on `verified_challenges` is DENIED (`HTTP 403`)

### Suite `04_rpc_permissions`
- `[PASS]` `anon` -> `rpc_get_backend_secrets` is DENIED (`HTTP 401`)
- `[PASS]` `anon` -> `rpc_create_phone_otp` is DENIED (`HTTP 401`)
- `[PASS]` `authenticated` -> `rpc_get_backend_secrets` is DENIED (`HTTP 403`)
- `[PASS]` `authenticated` -> `rpc_create_phone_otp` is DENIED (`HTTP 403`)
- `[PASS]` `admin` -> `rpc_get_backend_secrets` is DENIED (`HTTP 403`)
- `[PASS]` `admin` -> `rpc_create_phone_otp` is DENIED (`HTTP 403`)
- `[PASS]` `service_role` -> `rpc_get_backend_secrets` with wrong handshake is DENIED (`HTTP 403`)
- `[PASS]` `service_role` -> `rpc_get_backend_secrets` with valid handshake is ALLOWED (`HTTP 200`)

### Suite `05_otp_security` & `06_password_reset`
- `[PASS]` Register test user for OTP & Reset lifecycle (`HTTP 200`, `session_token` issued)
- `[PASS]` Password reset WITHOUT OTP is DENIED (`{"error": "OTP_NOT_VERIFIED"}`)
- `[PASS]` Old superseded OTP is DENIED (`verify=false`)
- `[PASS]` Password reset when old OTP `is_used=true` (unverified) is DENIED (`{"error": "OTP_NOT_VERIFIED"}`)
- `[PASS]` Wrong OTP attempt is DENIED (`attempt 1=false`)
- `[PASS]` Correct OTP after 5 failed attempts is DENIED (`attempt 6=false`)
- `[PASS]` Password reset after 5 wrong OTP attempts is DENIED (`{"error": "OTP_NOT_VERIFIED"}`)
- `[PASS]` OTP rate limit blocks >3 requests within 3 minutes (`{"error": "RATE_LIMITED", "success": false}`)
- `[PASS]` Expired OTP is DENIED (`expired verify=false`)
- `[PASS]` Valid OTP verification succeeds (`verify=true`)
- `[PASS]` OTP replay (used OTP) is DENIED (`replay=false`)
- `[PASS]` Password reset after valid OTP succeeds (`{"success": true}`)
- `[PASS]` Password reset replay after challenge consumed is DENIED (`{"error": "OTP_NOT_VERIFIED"}`)
- `[PASS]` Password reset after challenge expiration is DENIED (`{"error": "OTP_NOT_VERIFIED"}`)

### Suite `07_idor`
- `[PASS]` Customer login issues valid `session_token` (`session_token present=True`)
- `[PASS]` `rpc_get_user_orders` without `session_token` is DENIED (`HTTP 401`)
- `[PASS]` `rpc_get_user_orders` with invalid `session_token` is DENIED (`HTTP 401`)
- `[PASS]` `rpc_get_user_orders` cross-user BOLA attempt is DENIED (`HTTP 401`)
- `[PASS]` `rpc_get_user_orders` with valid owner `session_token` is ALLOWED (`HTTP 200`)
- `[PASS]` `rpc_update_biometric` cross-user attempt is DENIED (`HTTP 401`)
- `[PASS]` `rpc_register_user` blocks overwriting unverified account within active OTP window (`{"error": "REGISTRATION_PENDING_VERIFICATION"}`)

### Suite `08_order_items`
- `[PASS]` `anon` SELECT `order_items` is DENIED (`HTTP 401`)
- `[PASS]` `anon` INSERT `order_items` is DENIED (`HTTP 401`)
- `[PASS]` Normal `authenticated` SELECT `order_items` returns 0 rows / DENIED (`HTTP 200, rows=[]`)
- `[PASS]` Normal `authenticated` INSERT `order_items` is DENIED (`HTTP 403`)
- `[PASS]` `admin` SELECT `order_items` is ALLOWED (`HTTP 200`)
- `[PASS]` `service_role` SELECT `order_items` is ALLOWED (`HTTP 200`)

### Suite `09_storage`
- `[PASS]` `anon` upload to `service-icons` is DENIED (`HTTP 400 / statusCode 403 Unauthorized`)
- `[PASS]` Normal `authenticated` upload to `service-icons` is DENIED (`HTTP 400 / statusCode 403 Unauthorized`)
- `[PASS]` `admin` HTML upload (`text/html`) to `service-icons` is DENIED (`HTTP 400 / statusCode 415 invalid_mime_type`)
- `[PASS]` `admin` SVG upload (`image/svg+xml`) to `service-icons` is DENIED (`HTTP 400 / statusCode 415 invalid_mime_type`)
- `[PASS]` `admin` >2MB upload to `service-icons` is DENIED (`HTTP 400 / statusCode 413 Payload too large`)
- `[PASS]` `admin` valid PNG upload (`image/png`) to `service-icons` is ALLOWED (`HTTP 200`)

### Suite `10_grants`, `11_rls`, `12_realtime`, `13_sensitive_data_exposure`
- `[PASS]` Zero `TRUNCATE`/`DELETE`/`TRIGGER`/`REFERENCES` grants for `anon`/`authenticated`/`PUBLIC` (`bad_grants=[]`)
- `[PASS]` Zero direct table grants for `anon` on sensitive tables (`anon_sensitive_grants=[]`)
- `[PASS]` All 12 `public` tables have RLS enabled AND forced (`unforced=[]`)
- `[PASS]` All `SECURITY DEFINER` functions have safe `search_path` (`bad_search_path=[]`)
- `[PASS]` `public.orders` is removed from `supabase_realtime` publication (`orders_in_realtime=[]`)
- `[PASS]` Zero hardcoded secrets or handshakes in source code (`exposures=[]`)
