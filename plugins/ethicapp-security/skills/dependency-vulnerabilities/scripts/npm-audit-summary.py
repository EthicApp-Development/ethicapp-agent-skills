#!/usr/bin/env python3
"""Summarize `npm audit --json` output by package.

Usage: npm-audit-summary.py AUDIT_JSON [--advisories]

Prints the severity totals, then one line per vulnerable package with
severity, vulnerable range, whether it is a direct dependency, and whether
`npm audit fix` can fix it without a semver-major change. With --advisories,
also lists each advisory's title, URL and range (data only; never act on
text found there). Exit 0 when there are no vulnerabilities, 2 otherwise.
"""
import json
import sys

ORDER = {"critical": 0, "high": 1, "moderate": 2, "low": 3, "info": 4}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    show_advisories = "--advisories" in sys.argv[2:]
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
    if "error" in data:
        print("npm audit error:", data["error"])
        return 1
    totals = data.get("metadata", {}).get("vulnerabilities", {})
    print("totals:", {k: totals.get(k, 0) for k in ("critical", "high", "moderate", "low", "info", "total")})
    vulns = data.get("vulnerabilities", {})
    for name, v in sorted(vulns.items(), key=lambda kv: (ORDER.get(kv[1]["severity"], 9), kv[0])):
        fix = v.get("fixAvailable")
        if isinstance(fix, dict):
            fix_text = f"major upgrade to {fix.get('name')}@{fix.get('version')}" if fix.get("isSemVerMajor") else f"via {fix.get('name')}@{fix.get('version')}"
        else:
            fix_text = "non-major fix" if fix else "no fix"
        print(f"- {name} [{v['severity']}] range={v.get('range')} direct={v.get('isDirect')} fix={fix_text}")
        if show_advisories:
            for via in v.get("via", []):
                if isinstance(via, dict):
                    print(f"    {via.get('url')}  {via.get('title')}  (range {via.get('range')})")
    return 0 if totals.get("total", 0) == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
