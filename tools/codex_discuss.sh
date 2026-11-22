#!/bin/bash
# Design discussion with GPT through the Codex CLI on the user's ChatGPT
# subscription (never an API key). Read-only: Codex can look at the repo and
# the images but cannot change anything.
#
#   tools/codex_discuss.sh <topic> <question.md> [image ...]
#
# Writes project/discuss/<topic>.md (GPT's answer).
set -euo pipefail
cd "$(dirname "$0")/.."
TOPIC="$1"; QUESTION="$(cat "$2")"; shift 2
CODEX="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
MEMORY="$HOME/.claude/projects/-Users-shuiying-cameragr/memory"
OUT="project/discuss"
mkdir -p "$OUT"
/usr/bin/python3 .claude/skills/codex-image/run.py --check

IMAGES=()
for f in "$@"; do IMAGES+=(-i "$f"); done

PROMPT="You are the design partner for Koco, an iOS film-camera app for the foldable iPhone, working with the developer (another AI). Do not change any files.

Background, read as needed:
- $MEMORY/cameragr-product-decisions.md, $MEMORY/cameragr-working-preferences.md, $MEMORY/cameragr-no-self-retouch.md: settled decisions and the user's rules (skeuomorphic, GPT-drawn art, nothing web- or menu-like).
- project/BLUEPRINT.md and project/QUEUE.md: the plan and open questions.
- The source code in the repo; the attached images.

The developer asks:
$QUESTION

Answer in Chinese, as Markdown: first your honest critique, then concrete proposals (what it looks like, how it is used, why it fits the app's flow), ranked; say where you disagree with the developer. Be specific and brief; no filler."

rm -f "$OUT/$TOPIC.md"
perl -e 'alarm shift; exec @ARGV' 900 \
  "$CODEX" exec -s read-only --ephemeral -C "$PWD" -o "$OUT/$TOPIC.md" "$PROMPT" ${IMAGES[@]+"${IMAGES[@]}"} \
  < /dev/null > "$OUT/$TOPIC.log" 2>&1 || { echo "discussion failed or timed out: see $OUT/$TOPIC.log" >&2; exit 1; }
echo "$OUT/$TOPIC.md"
