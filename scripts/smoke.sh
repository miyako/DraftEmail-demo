#!/bin/sh
# Headless acceptance for this demo.
#
# Runs Demo_HeadlessSmoke with tool4d and prints the verdict. Nothing is
# composed, so no mail client opens and no draft is created.
#
#   scripts/smoke.sh [report.json]
#
# tool4d is looked up as $TOOL4D, then /Applications/4D */tool4d.app, then
# /Applications/tool4d.app. The component must already be resolvable -- see
# docs/FINDINGS.md ("tool4d cannot resolve a Dependency manager dependency").

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
report=${1:-/tmp/DraftEmail-demo-smoke.json}

if [ -z "${TOOL4D:-}" ]; then
	for candidate in /Applications/4D\ *"/tool4d.app/Contents/MacOS/tool4d" /Applications/tool4d.app/Contents/MacOS/tool4d; do
		if [ -x "$candidate" ]; then
			TOOL4D=$candidate
			break
		fi
	done
fi
if [ -z "${TOOL4D:-}" ] || [ ! -x "${TOOL4D:-}" ]; then
	echo "tool4d not found; set TOOL4D=/path/to/tool4d" >&2
	exit 2
fi

project="$root/Project/DraftEmail-demo.4DProject"
if [ ! -f "$project" ]; then
	echo "no project at $project" >&2
	exit 2
fi

rm -f "$report"
"$TOOL4D" --project "$project" --dataless --skip-onstartup \
	--startup-method=Demo_HeadlessSmoke \
	--user-param "{\"out\":\"$report\"}" >/dev/null 2>&1 || true

if [ ! -s "$report" ]; then
	echo "the smoke method wrote no report at $report" >&2
	echo "check that the DraftEmail component is resolvable (docs/FINDINGS.md §1)" >&2
	exit 1
fi

python3 - "$report" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
studio = report.get("studio", {})
print(f"report      {sys.argv[1]}")
print(f"compiled    {report.get('compiled')}")
print(f"studio      validate {studio.get('validate', {}).get('ok')} · cc rejected {studio.get('ccRejected', {}).get('ok') is False}")
print(f"seed        {json.dumps(studio.get('seed'))}")
print(f"scenarios   {report.get('summary')}")
for row in report.get("scenarios", []):
    if row.get("verdict") != "PASS":
        print(f"  FAIL {row.get('id')} expected {row.get('expect')} got {row.get('actual')}")
sys.exit(0 if report.get("passed") else 1)
PY
