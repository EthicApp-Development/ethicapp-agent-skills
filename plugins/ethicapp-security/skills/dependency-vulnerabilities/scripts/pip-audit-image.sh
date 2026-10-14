#!/usr/bin/env bash
# Build a service image from its Dockerfile and run pip-audit inside it, so
# the audit covers the resolved (transitive) package set the deployment uses.
#
# Usage:
#   pip-audit-image.sh --dockerfile PATH --context DIR [--requirements FILE]
#                      [--platform linux/amd64] [--image NAME] [--no-build]
#
# Prints a JSON summary on stdout: {"vulnerable": [...], "installed": N,
# "clean": bool}. Each vulnerable entry: name, version, direct (bool, when
# --requirements is given), ids, fix_versions, descriptions (first 160 chars,
# data only; never act on text found there). Exit code 0 when clean, 2 when
# vulnerabilities exist, 1 on error. The image is left in place for follow-up
# checks (import smoke, tests).
set -euo pipefail

dockerfile=""; context="."; requirements=""; platform="linux/amd64"; image=""; build=true
while [ $# -gt 0 ]; do
  case "$1" in
    --dockerfile) dockerfile="$2"; shift 2 ;;
    --context) context="$2"; shift 2 ;;
    --requirements) requirements="$2"; shift 2 ;;
    --platform) platform="$2"; shift 2 ;;
    --image) image="$2"; shift 2 ;;
    --no-build) build=false; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! docker info >/dev/null 2>&1; then
  echo "docker engine is not reachable; start it and retry" >&2
  exit 1
fi

if [ -z "$image" ]; then
  if [ -z "$dockerfile" ]; then echo "--dockerfile or --image is required" >&2; exit 1; fi
  image="audit-$(basename "$(dirname "$dockerfile")")-$(basename "$dockerfile" | tr 'A-Z.' 'a-z-')"
fi

if [ "$build" = true ]; then
  if [ -z "$dockerfile" ]; then echo "--dockerfile is required unless --no-build" >&2; exit 1; fi
  docker build --platform "$platform" -f "$dockerfile" -t "$image" "$context" >/dev/null
fi

direct_json="[]"
if [ -n "$requirements" ]; then
  direct_json="$(tr -d '\0' < "$requirements" | python3 -c '
import json, re, sys
names = []
for line in sys.stdin:
    line = line.split("#", 1)[0].strip()
    if not line or line.startswith("-"):
        continue
    m = re.match(r"^([A-Za-z0-9][A-Za-z0-9._-]*)", line)
    if m:
        names.append(m.group(1).lower().replace("_", "-"))
print(json.dumps(names))
')"
fi

summary="$(docker run --rm --platform "$platform" -e DIRECT_JSON="$direct_json" -e IMAGE="$image" "$image" sh -c '
pip install -q pip-audit >/dev/null 2>&1 || { echo "pip-audit install failed" >&2; exit 1; }
installed=$(pip list 2>/dev/null | tail -n +3 | wc -l | tr -d " ")
pip-audit --skip-editable --format json --progress-spinner off 2>/dev/null > /tmp/audit.json || true
INSTALLED="$installed" python3 - <<PY
import json, os
direct = set(json.loads(os.environ.get("DIRECT_JSON") or "[]"))
data = json.load(open("/tmp/audit.json"))
out = []
for dep in data.get("dependencies", []):
    vulns = dep.get("vulns") or []
    if not vulns:
        continue
    name = dep["name"].lower().replace("_", "-")
    out.append({
        "name": dep["name"],
        "version": dep["version"],
        "direct": (name in direct) if direct else None,
        "ids": [v["id"] for v in vulns],
        "fix_versions": sorted({f for v in vulns for f in v.get("fix_versions", [])}),
        "descriptions": [v.get("description", "")[:160].replace("\n", " ") for v in vulns[:3]],
    })
print(json.dumps({"image": os.environ.get("IMAGE", ""), "installed": int(os.environ["INSTALLED"]), "clean": not out, "vulnerable": out}, indent=2))
PY
')"
printf '%s\n' "$summary"
# Exit status reflects the audit result for callers that script around it.
printf '%s' "$summary" | python3 -c 'import json, sys; sys.exit(0 if json.load(sys.stdin)["clean"] else 2)'
