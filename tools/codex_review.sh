#!/bin/bash
# GPT review of one task, through the Codex CLI on the user's ChatGPT
# subscription (never an API key). Read-only: Codex can look at the repo and
# the screenshots but cannot change anything.
#
#   tools/codex_review.sh <task-id> <base-ref> [screenshot ...]
#
# Writes project/reviews/<task-id>.md (the review) and <task-id>.diff.
set -euo pipefail
cd "$(dirname "$0")/.."
TASK="$1"; BASE="$2"; shift 2
CODEX="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
MEMORY="$HOME/.claude/projects/-Users-shuiying-cameragr/memory"
OUT="project/reviews"
mkdir -p "$OUT"

# Same gate as image generation: ChatGPT sign-in, included quota, zero paid credits.
/usr/bin/python3 .claude/skills/codex-image/run.py --check

git diff "$BASE" -- . ':(exclude)*.lut' ':(exclude)*.jpg' ':(exclude)*.png' > "$OUT/$TASK.diff"
git status --short > "$OUT/$TASK.status"

IMAGES=()
for f in "$@"; do IMAGES+=(-i "$f"); done

PROMPT="You are the reviewer and tester for Koco, an iOS film-camera app (SwiftUI, Core Image, StoreKit 2), working with the developer (another AI) who just finished task $TASK. Do not change any files.

Read first:
- project/BLUEPRINT.md: the plan; find task $TASK and its done-criteria.
- project/QUEUE.md: decisions already taken or waiting.
- $MEMORY/cameragr-product-decisions.md and $MEMORY/cameragr-working-preferences.md: settled product decisions and the user's rules.
- $OUT/$TASK.diff: the change (binary assets left out), and $OUT/$TASK.status for new files; open any source file you need.
- The attached screenshots: the app as it now looks (the UI is drawn rotated on a portrait screen when it says so; judge it upright).

Then report, in Chinese, as Markdown with exactly these sections:
## 必须改  (bugs, crashes, data loss, broken purchase logic, text cut off, things that contradict a settled decision; each with file:line or screenshot, why, and a concrete fix)
## 建议改  (clear improvements worth doing now)
## 偏离蓝图  (anything outside task $TASK's scope or against the blueprint; say 'none' if none)
## 测试建议  (manual or automated checks the developer should still run)
## 结论  (one line: 通过 / 修改后通过 / 不通过)
Be specific and brief. Do not invent problems; if unsure, say so."

"$CODEX" exec -s read-only --ephemeral -C "$PWD" -o "$OUT/$TASK.md" "$PROMPT" ${IMAGES[@]+"${IMAGES[@]}"} > "$OUT/$TASK.log" 2>&1
echo "$OUT/$TASK.md"
