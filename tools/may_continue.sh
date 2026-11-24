#!/bin/bash
# Whether the autonomous chain may start another task now. Prints the reason
# and exits 0 (go) or 1 (stop).
#
#   tools/may_continue.sh <claude seven-day utilization, 0-1>
#
# Rules agreed with the user on 2026-11-21: run day and night; pause once
# this stint has used 10 points of either weekly quota (Claude or Codex)
# since the baseline in project/budget.json, and never go below 30% Codex.
# The pause holds until the user says to continue (then the baseline is reset).
cd "$(dirname "$0")/.."
CLAUDE_USED="${1:-}"
if [ -z "$CLAUDE_USED" ]; then echo "stop: Claude usage not given"; exit 1; fi
check=$(/usr/bin/python3 .claude/skills/codex-image/run.py --check 2>&1 | tail -1)
case "$check" in Preflight\ passed*) ;; *) echo "stop: Codex check failed: $check"; exit 1;; esac
left=$(echo "$check" | grep -oE '[0-9.]+% remaining' | grep -oE '^[0-9.]+' | sort -n | head -1)
/usr/bin/python3 - "$CLAUDE_USED" "${left:-0}" <<'PY'
import json, sys
claude, codex = float(sys.argv[1]), float(sys.argv[2])
b = json.load(open("project/budget.json"))
step = b.get("step", 10)
used_claude = (claude - b["claude_week_used"]) * 100
used_codex = b["codex_left"] - codex
if used_claude >= step:
    print(f"stop: Claude used {used_claude:.0f} points this stint (now {claude*100:.0f}%, from {b['claude_week_used']*100:.0f}%)"); sys.exit(1)
if used_codex >= step:
    print(f"stop: Codex used {used_codex:.0f} points this stint (now {codex:.0f}% left, from {b['codex_left']:.0f}%)"); sys.exit(1)
if codex < 30:
    print(f"stop: Codex only {codex:.0f}% left"); sys.exit(1)
print(f"go: Claude +{used_claude:.0f}/{step} points, Codex +{used_codex:.0f}/{step} points this stint")
PY
