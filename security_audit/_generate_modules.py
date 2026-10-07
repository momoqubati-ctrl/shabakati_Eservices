import os

MODULES = [
    "01_anon_access",
    "02_authenticated_access",
    "03_admin_access",
    "04_rpc_permissions",
    "05_otp_security",
    "06_password_reset",
    "07_idor",
    "08_order_items",
    "09_storage",
    "10_grants",
    "11_rls",
    "12_realtime",
    "13_sensitive_data_exposure",
]

base_dir = os.path.dirname(os.path.abspath(__file__))

for mod in MODULES:
    code = f'''"""
Security Regression Test Module: {mod}
Executes and filters results for {mod} from the live PostgREST/JWT audit suite.
"""
import json
import os
import sys
from run_all_audits import run_suite

if __name__ == "__main__":
    results_file = os.path.join(os.path.dirname(__file__), "audit_results.json")
    if not os.path.exists(results_file):
        run_suite()
    with open(results_file, encoding="utf-8") as f:
        data = json.load(f)
    filtered = [r for r in data.get("results", []) if r.get("suite") == "{mod}"]
    for r in filtered:
        print(f"[{{r['status']}}] {{r['test']}} -> {{r['evidence']}}")
    if any(r["status"] != "PASS" for r in filtered):
        sys.exit(1)
'''
    with open(os.path.join(base_dir, f"{mod}.py"), "w", encoding="utf-8") as f:
        f.write(code)

print("Generated all 13 security_audit module scripts.")
