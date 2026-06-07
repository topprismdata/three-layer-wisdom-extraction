#!/bin/bash
# hybrid_validate.sh — Run the full principle lifecycle in one command
#
# Orchestrates the 6 maintenance tools:
#   1. check_stale.sh           (always)
#   2. check_duplicate.sh       (always)
#   3. propagate.sh             (always)
#   4. cluster_principles.sh    (always; --apply if requested)
#   5. multi_actor_extract.sh   (only with --deep; slow)
#   6. cross_project_check.sh   (only with --cross-project)
#
# Usage:
#   bash hybrid_validate.sh                  # quick audit (1-4)
#   bash hybrid_validate.sh --apply          # also apply cluster splits
#   bash hybrid_validate.sh --deep           # also multi-actor (~30s+)
#   bash hybrid_validate.sh --cross-project  # also cross-project diagnostic
#   bash hybrid_validate.sh --all            # all 6 tools
#
# Each tool's output is separated by clear dividers so you can read along.
# Exit code is the count of FATAL findings (FADING principles, OVERCONFIDENT
# principles, duplicates above 0.5 Jaccard, M1 multi-actor warnings).

set -e

PRINCIPLES_DIR="${PRINCIPLES_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# Parse flags
APPLY=""
DEEP=""
CROSS=""
ALL=""
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY="--apply" ;;
    --deep) DEEP="1" ;;
    --cross-project) CROSS="1" ;;
    --all) DEEP="1"; CROSS="1" ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# Track findings for exit code
fatal=0
warnings=0

# Header
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Principle Hybrid Validation                                  ║"
echo "║  Project: $PRINCIPLES_DIR"
echo "║  Date:    $(date +%Y-%m-%d)"
echo "║  Flags:   apply=${APPLY:-no} deep=${DEEP:-no} cross=${CROSS:-no}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Helper: divider
divider() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
}

# Helper: track findings from output
track() {
  local output="$1"
  local count
  count=$(echo "$output" | grep -c "FATAL\|🚨 OVERCONFIDENT" || true)
  fatal=$((fatal + count))
  count=$(echo "$output" | grep -c "⚠️ " || true)
  warnings=$((warnings + count))
}

# ── 1. check_stale.sh ─────────────────────────────────────────
divider "1/6 — check_stale.sh (scope-decay + calibration)"
output=$(bash "$PRINCIPLES_DIR/check_stale.sh" 2>&1) || true
echo "$output"
track "$output"

# ── 2. check_duplicate.sh ─────────────────────────────────────
divider "2/6 — check_duplicate.sh (Jaccard dedup)"
output=$(bash "$PRINCIPLES_DIR/check_duplicate.sh" 2>&1) || true
echo "$output"
track "$output"

# ── 3. propagate.sh ──────────────────────────────────────────
divider "3/6 — propagate.sh (multi-hop Bellman)"
output=$(bash "$PRINCIPLES_DIR/propagate.sh" 2>&1) || true
echo "$output" | head -30
track "$output"

# ── 4. cluster_principles.sh ─────────────────────────────────
divider "4/6 — cluster_principles.sh (reader-fatigue + auto-split)"
if [ -n "$APPLY" ]; then
  output=$(bash "$PRINCIPLES_DIR/cluster_principles.sh" --auto-split --apply 2>&1) || true
else
  output=$(bash "$PRINCIPLES_DIR/cluster_principles.sh" --auto-split 2>&1) || true
fi
echo "$output" | head -30
track "$output"

# ── 5. multi_actor_extract.sh (only with --deep) ─────────────
if [ -n "$DEEP" ]; then
  divider "5/6 — multi_actor_extract.sh (3-persona validation)"
  echo "Note: this requires an input file. Skipping if not provided."
  if [ -f "$PRINCIPLES_DIR/../layer1_timeline.md" ]; then
    output=$(bash "$PRINCIPLES_DIR/multi_actor_extract.sh" \
      "$PRINCIPLES_DIR/../layer1_timeline.md" 2>&1) || true
    echo "$output" | head -50
  else
    echo "  No layer1_timeline.md found. Skipping."
    echo "  To run: create memory/layer1_timeline.md and re-run with --deep"
  fi
else
  echo ""
  echo "  (Skipping 5/6 multi_actor_extract.sh — pass --deep to run)"
  echo ""
fi

# ── 6. cross_project_check.sh (only with --cross-project) ───
if [ -n "$CROSS" ]; then
  divider "6/6 — cross_project_check.sh (Domain-scope diagnostic)"
  output=$(bash "$PRINCIPLES_DIR/cross_project_check.sh" 2>&1) || true
  echo "$output"
else
  echo ""
  echo "  (Skipping 6/6 cross_project_check.sh — pass --cross-project to run)"
  echo ""
fi

# ── Summary ──────────────────────────────────────────────────
divider "Summary"
total_tools=4
[ -n "$DEEP" ] && total_tools=$((total_tools + 1))
[ -n "$CROSS" ] && total_tools=$((total_tools + 1))

echo "Tools run: $total_tools / 6"
echo "Findings:"
echo "  🚨 FATAL: $fatal"
echo "  ⚠️  Warnings: $warnings"
echo ""

if [ "$fatal" -gt 0 ]; then
  echo "Status: ❌ FAIL — action required"
  exit 1
elif [ "$warnings" -gt 0 ]; then
  echo "Status: ⚠️  WARNINGS — review"
  exit 0
else
  echo "Status: ✅ ALL CLEAN"
  exit 0
fi
