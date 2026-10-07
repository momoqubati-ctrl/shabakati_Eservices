import os
import re
import json
import uuid
import hashlib
import requests
from _common import (
    SUPABASE_URL,
    ANON_KEY,
    ADMIN_USER_ID,
    NORMAL_USER_ID,
    get_db_conn,
    acquire_real_jwts,
    headers_for,
)

all_results = []


def record(suite, test_name, passed, evidence):
    status = "PASS" if passed else "FAIL"
    all_results.append({
        "suite": suite,
        "test": test_name,
        "status": status,
        "evidence": str(evidence)[:300],
    })
    icon = "✅ PASS" if passed else "❌ FAIL"
    print(f"[{suite}] {icon} | {test_name} -> {str(evidence)[:140]}", flush=True)


def run_suite():
    print("=" * 80)
    print("SHABAKATI — FULL PRODUCTION SECURITY AUDIT & REGRESSION SUITE")
    print("=" * 80)

    jwts = acquire_real_jwts()
    anon_h = headers_for(jwts["anon"])
    auth_h = headers_for(jwts["authenticated"])
    admin_h = headers_for(jwts["admin"])
    srv_h = headers_for(jwts["service_role"])

    record("00_jwt_setup", "Real GoTrue JWT acquired for normal authenticated user", bool(jwts["authenticated"]), f"JWT length={len(jwts['authenticated'] or '')}")
    record("00_jwt_setup", "Real GoTrue JWT acquired for admin user", bool(jwts["admin"]), f"JWT length={len(jwts['admin'] or '')}")

    # =========================================================================
    # 01_anon_access
    # =========================================================================
    for tbl in ["orders", "order_items", "payments", "payment_logs", "app_users", "phone_otps", "backend_secrets", "verified_challenges"]:
        r = requests.get(f"{SUPABASE_URL}/rest/v1/{tbl}?limit=1", headers=anon_h)
        record("01_anon_access", f"anon SELECT on {tbl} is DENIED", r.status_code in (401, 403), f"HTTP {r.status_code}")

    for tbl, payload in [
        ("app_settings", {"id": "evil"}),
        ("product_settings", {"product_id": 999999, "sku": "evil"}),
    ]:
        r_read = requests.get(f"{SUPABASE_URL}/rest/v1/{tbl}?limit=1", headers=anon_h)
        r_write = requests.post(f"{SUPABASE_URL}/rest/v1/{tbl}", headers=anon_h, json=payload)
        record("01_anon_access", f"anon SELECT on {tbl} is ALLOWED", r_read.status_code == 200, f"HTTP {r_read.status_code}")
        record("01_anon_access", f"anon WRITE on {tbl} is DENIED", r_write.status_code in (401, 403), f"HTTP {r_write.status_code}")

    # =========================================================================
    # 02_authenticated_access (Normal user role != admin)
    # =========================================================================
    for tbl in ["orders", "order_items", "payments", "payment_logs", "app_users"]:
        r = requests.get(f"{SUPABASE_URL}/rest/v1/{tbl}?limit=5", headers=auth_h)
        denied = (r.status_code in (401, 403)) or (r.status_code == 200 and r.json() == [])
        record("02_authenticated_access", f"normal authenticated SELECT on {tbl} returns 0 rows / DENIED", denied, f"HTTP {r.status_code}, rows={len(r.json()) if r.ok else 'denied'}")

    r_app_w = requests.post(
        f"{SUPABASE_URL}/rest/v1/app_settings",
        headers={**auth_h, "Prefer": "resolution=merge-duplicates"},
        json={"id": "general_settings", "usd_to_yer_rate": 1},
    )
    record("02_authenticated_access", "normal authenticated WRITE on app_settings is DENIED", r_app_w.status_code in (401, 403), f"HTTP {r_app_w.status_code}")

    r_prod_w = requests.post(
        f"{SUPABASE_URL}/rest/v1/product_settings",
        headers={**auth_h, "Prefer": "resolution=merge-duplicates"},
        json={"product_id": 999999, "sku": "test_evil", "custom_price_yer": 1},
    )
    record("02_authenticated_access", "normal authenticated WRITE on product_settings is DENIED", r_prod_w.status_code in (401, 403), f"HTTP {r_prod_w.status_code}")

    # =========================================================================
    # 03_admin_access (Admin user app_metadata.role == admin)
    # =========================================================================
    for tbl in ["orders", "order_items", "payments", "payment_logs", "app_users", "app_settings", "product_settings"]:
        r = requests.get(f"{SUPABASE_URL}/rest/v1/{tbl}?limit=2", headers=admin_h)
        record("03_admin_access", f"admin SELECT on {tbl} is ALLOWED", r.status_code == 200 and isinstance(r.json(), list), f"HTTP {r.status_code}, count={len(r.json()) if r.ok else 'err'}")

    for tbl in ["backend_secrets", "phone_otps", "verified_challenges"]:
        r = requests.get(f"{SUPABASE_URL}/rest/v1/{tbl}?limit=1", headers=admin_h)
        record("03_admin_access", f"admin direct SELECT on {tbl} is DENIED", r.status_code in (401, 403), f"HTTP {r.status_code}")

    # =========================================================================
    # 04_rpc_permissions
    # =========================================================================
    for role_name, hdr in [("anon", anon_h), ("authenticated", auth_h), ("admin", admin_h)]:
        r_sec = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_get_backend_secrets",
            headers=hdr,
            json={"p_handshake": "shabakti_srv_vault_handshake_2026_v1"},
        )
        record("04_rpc_permissions", f"{role_name} -> rpc_get_backend_secrets is DENIED", r_sec.status_code in (401, 403), f"HTTP {r_sec.status_code}")

        r_otp = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp",
            headers=hdr,
            json={"p_phone": "+967700000001", "p_clean_phone": "967700000001", "p_otp": "1111", "p_channel": "whatsapp"},
        )
        record("04_rpc_permissions", f"{role_name} -> rpc_create_phone_otp is DENIED", r_otp.status_code in (401, 403), f"HTTP {r_otp.status_code}")

    r_srv_sec_bad = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/rpc_get_backend_secrets",
        headers=srv_h,
        json={"p_handshake": "wrong_handshake"},
    )
    record("04_rpc_permissions", "service_role -> rpc_get_backend_secrets with wrong handshake is DENIED", r_srv_sec_bad.status_code in (400, 401, 403, 500), f"HTTP {r_srv_sec_bad.status_code}")

    r_srv_sec_ok = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/rpc_get_backend_secrets",
        headers=srv_h,
        json={"p_handshake": "shabakti_srv_vault_handshake_2026_v1"},
    )
    record("04_rpc_permissions", "service_role -> rpc_get_backend_secrets with valid handshake is ALLOWED", r_srv_sec_ok.status_code == 200, f"HTTP {r_srv_sec_ok.status_code}")

    # =========================================================================
    # 05_otp_security & 06_password_reset
    # =========================================================================
    conn = get_db_conn()
    conn.autocommit = True
    cur = conn.cursor()

    test_phone = "+967799998877"
    test_clean = "967799998877"
    test_nat = "799998877"
    init_hash = hashlib.sha256(f"{test_phone}:1234:shabakti_sec_v1".encode()).hexdigest()
    new_hash = hashlib.sha256(f"{test_phone}:5678:shabakti_sec_v1".encode()).hexdigest()

    try:
        # Clean up any prior test data
        cur.execute("DELETE FROM public.verified_challenges WHERE clean_phone = %s OR phone = %s;", (test_clean, test_phone))
        cur.execute("DELETE FROM public.phone_otps WHERE phone IN (%s, %s);", (test_phone, test_clean))
        cur.execute("DELETE FROM public.app_users WHERE account_number = %s;", (test_phone,))

        # Register test user
        r_reg = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_register_user",
            headers=anon_h,
            json={
                "p_account_number": test_phone,
                "p_dial_code": "+967",
                "p_phone_national": test_nat,
                "p_full_name": "Test Security User",
                "p_region": "A",
                "p_password_hash": init_hash,
            },
        )
        reg_data = r_reg.json() if r_reg.ok else {}
        record("05_otp_security", "Register test user for OTP & Reset lifecycle", r_reg.status_code == 200 and "session_token" in reg_data, f"HTTP {r_reg.status_code}, id={reg_data.get('id')}")

        # Test 9: Password reset without OTP
        r_rst_no_otp = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_reset_password",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_clean_phone": test_clean, "p_new_hash": new_hash},
        )
        record("06_password_reset", "Password reset WITHOUT OTP is DENIED", r_rst_no_otp.json().get("error") == "OTP_NOT_VERIFIED", r_rst_no_otp.text)

        # Create OTP #1 via service_role
        requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp",
            headers=srv_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "4321", "p_channel": "whatsapp"},
        )
        # Immediately create OTP #2 via service_role (marks OTP #1 is_used=true)
        requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp",
            headers=srv_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "8765", "p_channel": "whatsapp"},
        )

        # Test 5: Old OTP #1 rejected
        r_old_otp = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/verify_phone_otp",
            headers=anon_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "4321"},
        )
        record("05_otp_security", "Old superseded OTP is DENIED", r_old_otp.json() is False, f"verify={r_old_otp.text}")

        # Exploit check: OTP #1 is now is_used=true, try resetting password without verifying OTP #2!
        r_rst_Premature = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_reset_password",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_clean_phone": test_clean, "p_new_hash": new_hash},
        )
        record("06_password_reset", "Password reset when old OTP is_used=true (unverified) is DENIED", r_rst_Premature.json().get("error") == "OTP_NOT_VERIFIED", r_rst_Premature.text)

        # Test 2 & 6: Wrong OTP & 5 failed attempts lock OTP #2
        for attempt in range(5):
            r_wrong = requests.post(
                f"{SUPABASE_URL}/rest/v1/rpc/verify_phone_otp",
                headers=anon_h,
                json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "0000"},
            )
            if attempt == 0:
                record("05_otp_security", "Wrong OTP attempt is DENIED", r_wrong.json() is False, f"attempt 1={r_wrong.text}")

        # 6th attempt with the CORRECT code "8765" must now fail because 5 wrong attempts exhausted it
        r_after_5 = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/verify_phone_otp",
            headers=anon_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "8765"},
        )
        record("05_otp_security", "Correct OTP after 5 failed attempts is DENIED", r_after_5.json() is False, f"attempt 6={r_after_5.text}")

        # Test 11: Password reset after 5 wrong OTP attempts (which set is_used=true) must be DENIED
        r_rst_after_wrong = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_reset_password",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_clean_phone": test_clean, "p_new_hash": new_hash},
        )
        record("06_password_reset", "Password reset after 5 wrong OTP attempts is DENIED", r_rst_after_wrong.json().get("error") == "OTP_NOT_VERIFIED", r_rst_after_wrong.text)

        # Test 7: Request 3rd OTP -> allowed, 4th OTP within 3 minutes -> RATE_LIMITED
        r_otp3 = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp",
            headers=srv_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "9988", "p_channel": "whatsapp"},
        )
        r_otp4 = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp",
            headers=srv_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "7766", "p_channel": "whatsapp"},
        )
        record("05_otp_security", "OTP rate limit blocks >3 requests within 3 minutes", r_otp4.json().get("error") == "RATE_LIMITED", r_otp4.text)

        # Test 3: Expired OTP check
        cur.execute("UPDATE public.phone_otps SET expires_at = now() - interval '1 minute' WHERE phone = %s AND otp_code = '9988';", (test_phone,))
        r_exp = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/verify_phone_otp",
            headers=anon_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "9988"},
        )
        record("05_otp_security", "Expired OTP is DENIED", r_exp.json() is False, f"expired verify={r_exp.text}")

        # Reset rate limit window for test phone and issue fresh valid OTP "5544"
        cur.execute("DELETE FROM public.phone_otps WHERE phone = %s;", (test_phone,))
        requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp",
            headers=srv_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "5544", "p_channel": "whatsapp"},
        )

        # Test 1: Correct OTP succeeds
        r_valid_otp = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/verify_phone_otp",
            headers=anon_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "5544"},
        )
        record("05_otp_security", "Valid OTP verification succeeds", r_valid_otp.json() is True, f"verify={r_valid_otp.text}")

        # Test 4 & 8: Used OTP / Replay of same OTP is DENIED
        r_replay_otp = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/verify_phone_otp",
            headers=anon_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "5544"},
        )
        record("05_otp_security", "OTP replay (used OTP) is DENIED", r_replay_otp.json() is False, f"replay={r_replay_otp.text}")

        # Test 10: Password reset after valid OTP succeeds
        r_rst_ok = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_reset_password",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_clean_phone": test_clean, "p_new_hash": new_hash},
        )
        record("06_password_reset", "Password reset after valid OTP succeeds", r_rst_ok.json().get("success") is True, r_rst_ok.text)

        # Test 12a: Password reset replay with already-consumed challenge is DENIED
        r_rst_replay = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_reset_password",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_clean_phone": test_clean, "p_new_hash": init_hash},
        )
        record("06_password_reset", "Password reset replay after challenge consumed is DENIED", r_rst_replay.json().get("error") == "OTP_NOT_VERIFIED", r_rst_replay.text)

        # Test 12b: Password reset after challenge expired is DENIED
        requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp",
            headers=srv_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "6655", "p_channel": "whatsapp"},
        )
        requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/verify_phone_otp",
            headers=anon_h,
            json={"p_phone": test_phone, "p_clean_phone": test_clean, "p_otp": "6655"},
        )
        cur.execute("UPDATE public.verified_challenges SET expires_at = now() - interval '1 minute' WHERE clean_phone = %s;", (test_clean,))
        r_rst_exp = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_reset_password",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_clean_phone": test_clean, "p_new_hash": init_hash},
        )
        record("06_password_reset", "Password reset after challenge expiration is DENIED", r_rst_exp.json().get("error") == "OTP_NOT_VERIFIED", r_rst_exp.text)

        # =====================================================================
        # 07_idor (rpc_get_user_orders, rpc_update_biometric, rpc_register_user)
        # =====================================================================
        # Login as test user to get valid session_token
        r_login = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_login_user",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_password_hash": new_hash},
        )
        login_data = r_login.json()
        user_a_token = login_data.get("session_token")
        user_a_id = login_data.get("id")
        record("07_idor", "Customer login issues valid session_token", bool(user_a_token), f"session_token present={bool(user_a_token)}")

        # 1. Call rpc_get_user_orders without session_token -> DENIED
        r_idor_no_tok = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_get_user_orders",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_phone_national": test_nat, "p_user_id": user_a_id},
        )
        record("07_idor", "rpc_get_user_orders without session_token is DENIED", r_idor_no_tok.status_code in (401, 403), f"HTTP {r_idor_no_tok.status_code}")

        # 2. Call rpc_get_user_orders with fake session_token -> DENIED
        r_idor_fake_tok = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_get_user_orders",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_session_token": str(uuid.uuid4())},
        )
        record("07_idor", "rpc_get_user_orders with invalid session_token is DENIED", r_idor_fake_tok.status_code in (401, 403), f"HTTP {r_idor_fake_tok.status_code}")

        # 3. Call rpc_get_user_orders with User A's session_token but User B's account_number -> DENIED
        r_idor_cross = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_get_user_orders",
            headers=anon_h,
            json={"p_account_number": "+967777000111", "p_session_token": user_a_token},
        )
        record("07_idor", "rpc_get_user_orders cross-user BOLA attempt is DENIED", r_idor_cross.status_code in (401, 403), f"HTTP {r_idor_cross.status_code}")

        # 4. Call rpc_get_user_orders with User A's session_token and User A's account_number -> ALLOWED
        r_idor_own = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_get_user_orders",
            headers=anon_h,
            json={"p_account_number": test_phone, "p_phone_national": test_nat, "p_user_id": user_a_id, "p_session_token": user_a_token},
        )
        record("07_idor", "rpc_get_user_orders with valid owner session_token is ALLOWED", r_idor_own.status_code == 200 and isinstance(r_idor_own.json(), list), f"HTTP {r_idor_own.status_code}")

        # 5. Call rpc_update_biometric without token or for another user -> DENIED
        r_bio_unauth = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_update_biometric",
            headers=anon_h,
            json={"p_account_number": "+967777000111", "p_enabled": False, "p_session_token": user_a_token},
        )
        record("07_idor", "rpc_update_biometric cross-user attempt is DENIED", r_bio_unauth.status_code in (401, 403), f"HTTP {r_bio_unauth.status_code}")

        # 6. Test unverified account overwrite protection in rpc_register_user
        unver_phone = "+967799998866"
        cur.execute("DELETE FROM public.app_users WHERE account_number = %s;", (unver_phone,))
        requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_register_user",
            headers=anon_h,
            json={
                "p_account_number": unver_phone,
                "p_dial_code": "+967",
                "p_phone_national": "799998866",
                "p_full_name": "Original Owner",
                "p_region": "A",
                "p_password_hash": init_hash,
            },
        )
        r_overwrite = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/rpc_register_user",
            headers=anon_h,
            json={
                "p_account_number": unver_phone,
                "p_dial_code": "+967",
                "p_phone_national": "799998866",
                "p_full_name": "Attacker Overwrite",
                "p_region": "B",
                "p_password_hash": new_hash,
            },
        )
        record("07_idor", "rpc_register_user blocks overwriting unverified account within active OTP window", r_overwrite.json().get("error") == "REGISTRATION_PENDING_VERIFICATION", r_overwrite.text)

    finally:
        cur.execute("DELETE FROM public.verified_challenges WHERE clean_phone = %s OR phone = %s;", (test_clean, test_phone))
        cur.execute("DELETE FROM public.phone_otps WHERE phone IN (%s, %s);", (test_phone, test_clean))
        cur.execute("DELETE FROM public.app_users WHERE account_number IN (%s, '+967799998866');", (test_phone,))

    # =========================================================================
    # 08_order_items
    # =========================================================================
    r_oi_anon_s = requests.get(f"{SUPABASE_URL}/rest/v1/order_items?limit=1", headers=anon_h)
    r_oi_anon_i = requests.post(f"{SUPABASE_URL}/rest/v1/order_items", headers=anon_h, json={"order_id": 1, "product_id": 1, "product_name": "x", "quantity": 1, "unit_price_cents": 100})
    r_oi_auth_s = requests.get(f"{SUPABASE_URL}/rest/v1/order_items?limit=1", headers=auth_h)
    r_oi_auth_i = requests.post(f"{SUPABASE_URL}/rest/v1/order_items", headers=auth_h, json={"order_id": 1, "product_id": 1, "product_name": "x", "quantity": 1, "unit_price_cents": 100})
    r_oi_adm_s = requests.get(f"{SUPABASE_URL}/rest/v1/order_items?limit=1", headers=admin_h)
    r_oi_srv_s = requests.get(f"{SUPABASE_URL}/rest/v1/order_items?limit=1", headers=srv_h)

    record("08_order_items", "anon SELECT order_items is DENIED", r_oi_anon_s.status_code in (401, 403), f"HTTP {r_oi_anon_s.status_code}")
    record("08_order_items", "anon INSERT order_items is DENIED", r_oi_anon_i.status_code in (401, 403), f"HTTP {r_oi_anon_i.status_code}")
    record("08_order_items", "normal authenticated SELECT order_items returns 0 rows / DENIED", r_oi_auth_s.status_code in (401, 403) or r_oi_auth_s.json() == [], f"HTTP {r_oi_auth_s.status_code}, rows={r_oi_auth_s.text}")
    record("08_order_items", "normal authenticated INSERT order_items is DENIED", r_oi_auth_i.status_code in (401, 403), f"HTTP {r_oi_auth_i.status_code}")
    record("08_order_items", "admin SELECT order_items is ALLOWED", r_oi_adm_s.status_code == 200, f"HTTP {r_oi_adm_s.status_code}")
    record("08_order_items", "service_role SELECT order_items is ALLOWED", r_oi_srv_s.status_code == 200, f"HTTP {r_oi_srv_s.status_code}")

    # =========================================================================
    # 09_storage (service-icons bucket)
    # =========================================================================
    # 1. anon upload PNG -> DENY
    png_1x1 = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    r_st_anon = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/service-icons/audit_anon.png",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {jwts['anon']}", "Content-Type": "image/png"},
        data=png_1x1,
    )
    record("09_storage", "anon upload to service-icons is DENIED", r_st_anon.status_code in (400, 401, 403), f"HTTP {r_st_anon.status_code}: {r_st_anon.text[:80]}")

    # 2. normal authenticated upload PNG -> DENY
    r_st_auth = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/service-icons/audit_auth.png",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {jwts['authenticated']}", "Content-Type": "image/png"},
        data=png_1x1,
    )
    record("09_storage", "normal authenticated upload to service-icons is DENIED", r_st_auth.status_code in (400, 401, 403), f"HTTP {r_st_auth.status_code}: {r_st_auth.text[:80]}")

    # 3. admin HTML upload -> DENY
    r_st_html = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/service-icons/audit_evil.html",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {jwts['admin']}", "Content-Type": "text/html"},
        data=b"<html><script>alert(1)</script></html>",
    )
    record("09_storage", "admin HTML upload to service-icons is DENIED", r_st_html.status_code in (400, 403, 415, 422), f"HTTP {r_st_html.status_code}: {r_st_html.text[:80]}")

    # 4. admin SVG upload -> DENY
    r_st_svg = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/service-icons/audit_evil.svg",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {jwts['admin']}", "Content-Type": "image/svg+xml"},
        data=b"<svg xmlns='http://www.w3.org/2000/svg'></svg>",
    )
    record("09_storage", "admin SVG upload to service-icons is DENIED", r_st_svg.status_code in (400, 403, 415, 422), f"HTTP {r_st_svg.status_code}: {r_st_svg.text[:80]}")

    # 5. admin >2MB upload -> DENY
    r_st_big = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/service-icons/audit_big.png",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {jwts['admin']}", "Content-Type": "image/png"},
        data=b"\x89PNG\r\n\x1a\n" + (b"\x00" * (2 * 1024 * 1024 + 1024)),
    )
    record("09_storage", "admin >2MB upload to service-icons is DENIED", r_st_big.status_code in (400, 403, 413, 422), f"HTTP {r_st_big.status_code}: {r_st_big.text[:80]}")

    # 6. admin valid PNG upload -> ALLOW (and cleanup)
    r_st_png = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/service-icons/audit_valid.png",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {jwts['admin']}", "Content-Type": "image/png", "x-upsert": "true"},
        data=png_1x1,
    )
    record("09_storage", "admin valid PNG upload to service-icons is ALLOWED", r_st_png.status_code == 200, f"HTTP {r_st_png.status_code}: {r_st_png.text[:80]}")
    requests.delete(
        f"{SUPABASE_URL}/storage/v1/object/service-icons/audit_valid.png",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {jwts['admin']}"},
    )

    # =========================================================================
    # 10_grants, 11_rls, 12_realtime
    # =========================================================================
    cur.execute("""
        SELECT grantee, table_name, privilege_type
        FROM information_schema.role_table_grants
        WHERE table_schema = 'public'
          AND grantee IN ('anon', 'authenticated', 'PUBLIC')
          AND privilege_type IN ('TRUNCATE', 'DELETE', 'TRIGGER', 'REFERENCES');
    """)
    bad_grants = cur.fetchall()
    record("10_grants", "Zero TRUNCATE/DELETE/TRIGGER/REFERENCES grants for anon/authenticated/PUBLIC", len(bad_grants) == 0, f"bad_grants={bad_grants}")

    cur.execute("""
        SELECT table_name, privilege_type
        FROM information_schema.role_table_grants
        WHERE table_schema = 'public'
          AND grantee = 'anon'
          AND table_name NOT IN ('app_settings', 'product_settings', 'categories', 'cached_products');
    """)
    anon_sens_grants = cur.fetchall()
    record("10_grants", "Zero direct table grants for anon on sensitive tables", len(anon_sens_grants) == 0, f"anon_sensitive_grants={anon_sens_grants}")

    cur.execute("""
        SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relkind = 'r'
          AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity);
    """)
    unforced_rls = cur.fetchall()
    record("11_rls", "All public tables have RLS enabled AND forced", len(unforced_rls) == 0, f"unforced={unforced_rls}")

    cur.execute("""
        SELECT p.proname, p.proconfig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.prosecdef = true;
    """)
    secdef_funcs = cur.fetchall()
    bad_search_path = [
        (name, cfg) for name, cfg in secdef_funcs
        if not cfg or not any("pg_temp" in c or "pg_catalog" in c for c in cfg)
    ]
    record("11_rls", "All SECURITY DEFINER functions have safe search_path (public, pg_temp / pg_catalog)", len(bad_search_path) == 0, f"bad_search_path={bad_search_path}")

    cur.execute("""
        SELECT tablename
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'orders';
    """)
    orders_in_rt = cur.fetchall()
    record("12_realtime", "public.orders is removed from supabase_realtime publication", len(orders_in_rt) == 0, f"orders_in_realtime={orders_in_rt}")

    conn.close()

    # =========================================================================
    # 13_sensitive_data_exposure
    # =========================================================================
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    scan_dirs = ["lib", "api", os.path.join("admin_dashboard", "src"), os.path.join("admin_dashboard", "public")]
    forbidden_patterns = [
        ("hardcoded_handshake", re.compile(r"shabakti_srv_vault_handshake_2026_v1")),
        ("hardcoded_service_role_jwt", re.compile(r"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[A-Za-z0-9_-]*c2VydmljZV9yb2xl[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+")),
        ("vite_digital_vault_secret", re.compile(r"VITE_DIGITAL_VAULT_API_SECRET")),
    ]
    exposures = []
    for sdir in scan_dirs:
        full_sdir = os.path.join(root_dir, sdir)
        if not os.path.exists(full_sdir):
            continue
        for dirpath, _, filenames in os.walk(full_sdir):
            for fn in filenames:
                if fn.endswith((".dart", ".js", ".jsx", ".ts", ".tsx", ".html", ".json")):
                    fpath = os.path.join(dirpath, fn)
                    with open(fpath, encoding="utf-8", errors="ignore") as f:
                        content = f.read()
                    for label, pat in forbidden_patterns:
                        if pat.search(content):
                            exposures.append(f"{label} in {os.path.relpath(fpath, root_dir)}")

    record("13_sensitive_data_exposure", "Zero hardcoded secrets or handshakes in source code (lib, api, admin_dashboard)", len(exposures) == 0, f"exposures={exposures}")

    # Summary
    passed_count = sum(1 for r in all_results if r["status"] == "PASS")
    failed_count = sum(1 for r in all_results if r["status"] == "FAIL")
    print("=" * 80)
    print(f"TOTAL TESTS: {len(all_results)} | PASSED: {passed_count} | FAILED: {failed_count}")
    print("=" * 80)

    out_path = os.path.join(os.path.dirname(__file__), "audit_results.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "total": len(all_results),
                "passed": passed_count,
                "failed": failed_count,
                "results": all_results,
            },
            f,
            indent=2,
            ensure_ascii=False,
        )

    if failed_count > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    run_suite()
