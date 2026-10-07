import os
import sys
import io
import json
import psycopg2
import requests

if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://enutfwspwrzpvhmtgftl.supabase.co")
ANON_KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs")
CONN_STR = os.environ.get("DATABASE_URL", "")

ADMIN_USER_ID = "4cc66948-3cc6-4f6f-a971-2dd4120e022d"
ADMIN_EMAIL = "admin@shabakti.com"
NORMAL_USER_ID = "364ab8b2-26f5-41d0-b615-f52569d35a8c"
NORMAL_EMAIL = "admin.shabakti.test7964@gmail.com"


def load_service_role_key():
    env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".env"))
    if os.path.exists(env_path):
        with open(env_path, encoding="utf-8", errors="ignore") as f:
            for line in f:
                if line.strip().startswith("SUPABASE_SERVICE_ROLE_KEY="):
                    return line.strip().split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")


def get_db_conn():
    return psycopg2.connect(CONN_STR)


def acquire_real_jwts():
    """
    Obtains real GoTrue JWTs for:
      - anon
      - normal_authenticated (role=authenticated, no admin role)
      - admin (role=authenticated, app_metadata.role=admin)
      - service_role
    Preserves and restores original encrypted_password & email_confirmed_at in auth.users.
    """
    conn = get_db_conn()
    conn.autocommit = True
    cur = conn.cursor()

    cur.execute(
        "SELECT id, encrypted_password, email_confirmed_at FROM auth.users WHERE id IN (%s, %s);",
        (ADMIN_USER_ID, NORMAL_USER_ID),
    )
    saved = {row[0]: (row[1], row[2]) for row in cur.fetchall()}
    temp_pass = "Shabakati_Audit_Temp#2026!"

    try:
        cur.execute(
            """
            UPDATE auth.users
            SET encrypted_password = extensions.crypt(%s, extensions.gen_salt('bf')),
                email_confirmed_at = COALESCE(email_confirmed_at, now())
            WHERE id IN (%s, %s);
            """,
            (temp_pass, ADMIN_USER_ID, NORMAL_USER_ID),
        )

        # Login as normal authenticated user
        r_norm = requests.post(
            f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
            headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
            json={"email": NORMAL_EMAIL, "password": temp_pass},
            timeout=15,
        )
        norm_token = r_norm.json().get("access_token") if r_norm.ok else None

        # Login as admin user
        r_adm = requests.post(
            f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
            headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
            json={"email": ADMIN_EMAIL, "password": temp_pass},
            timeout=15,
        )
        adm_token = r_adm.json().get("access_token") if r_adm.ok else None

        return {
            "anon": ANON_KEY,
            "authenticated": norm_token,
            "admin": adm_token,
            "service_role": load_service_role_key(),
        }
    finally:
        for uid, (orig_pw, orig_conf) in saved.items():
            cur.execute(
                "UPDATE auth.users SET encrypted_password = %s, email_confirmed_at = %s WHERE id = %s;",
                (orig_pw, orig_conf, uid),
            )
        conn.close()


def headers_for(token):
    return {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
