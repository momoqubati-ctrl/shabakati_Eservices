"""
Security Regression Test Module: 09_storage
Executes and filters results for 09_storage from the live PostgREST/JWT audit suite.
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
    filtered = [r for r in data.get("results", []) if r.get("suite") == "09_storage"]
    for r in filtered:
        print(f"[{r['status']}] {r['test']} -> {r['evidence']}")
    if any(r["status"] != "PASS" for r in filtered):
        sys.exit(1)
