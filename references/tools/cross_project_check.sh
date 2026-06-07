#!/bin/bash
# cross_project_check.sh — Validate principles against a hypothetical second project.
#
# Asks 4 diagnostic questions (one per principle by index modulo 4). If Yes,
# the principle is likely to apply in a new ML project. If No, the principle
# may be Domain-specific and should be demoted to scope=Project.
#
# This is a thinking scaffold, NOT a second project runner.
#
# Usage: bash cross_project_check.sh
#
# Customization: Edit PRINCIPLE_TO_QUESTION array to add more diagnostic
# questions for additional principles. The script auto-discovers all
# principles from .md files in PRINCIPLES_DIR.

set -e

# PRINCIPLES_DIR can be set via env var, otherwise default to script's dir
PRINCIPLES_DIR="${PRINCIPLES_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# Generic diagnostic questions (1 per principle, cycled with modulo)
# Customize by editing this array
declare -a PRINCIPLE_TO_QUESTION=(
  "Q1: Does the project have a metric (e.g., AUC, logloss, MAE, RMSE) that you can improve without actually moving the target?"
  "Q2: Does the project have features whose value at inference differs from training? (e.g., temporal drift, distribution shift, missing data)"
  "Q3: Does the project ensemble multiple models with possibly correlated outputs?"
  "Q4: Does the project tune hyperparameters (lr, rounds, depth, etc.) on a fixed validation set?"
)

echo "=== Cross-Project Validation (Domain-scope Diagnostic) ==="
echo ""
echo "For each principle, this script asks a diagnostic question that, if Yes,"
echo "the principle is likely to apply in a second ML project. If NO, the principle"
echo "may be Domain-specific (only this project) and not generalizable."
echo ""
echo "This is NOT running a second project. It's a thought-experiment scaffold."
echo ""

# Auto-discover principles from any *.md file in PRINCIPLES_DIR
# (skip README, SKILL, 16-principles, anything in references/ that isn't a principle file)
declare -a PRINCIPLE_NAMES=()
TMP_PRINCIPLES=$(mktemp)
trap "rm -f $TMP_PRINCIPLES" EXIT
for f in "$PRINCIPLES_DIR"/*.md; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  [ "$fname" = "README.md" ] && continue
  [ "$fname" = "SKILL.md" ] && continue
  [ "$fname" = "16-principles.md" ] && continue

  awk -v fname="$fname" '
    /^## (Principle|principle)/ {
      label = $0
      sub(/^## */, "", label)
      gsub(/^Principle [0-9]+: */, "", label)
      print fname "\t" label
    }
  ' "$f" >> "$TMP_PRINCIPLES"
done

# Deduplicate by label (some files may have repeated principles)
sort -u -t$'\t' -k2,2 "$TMP_PRINCIPLES" > "${TMP_PRINCIPLES}.uniq"
mv "${TMP_PRINCIPLES}.uniq" "$TMP_PRINCIPLES"

while IFS=$'\t' read -r fname pname; do
  [ -z "$pname" ] && continue
  PRINCIPLE_NAMES+=("$pname")
done < "$TMP_PRINCIPLES"

n_principles=${#PRINCIPLE_NAMES[@]}
n_questions=${#PRINCIPLE_TO_QUESTION[@]}
echo "Found $n_principles principles, $n_questions diagnostic questions."
echo ""
if [ "$n_principles" -gt "$n_questions" ]; then
  echo "WARNING: more principles than questions. Add more PRINCIPLE_TO_QUESTION entries."
  echo "         (questions will cycle with modulo: principle N uses question N % $n_questions)"
fi
echo ""

# For each principle, show the diagnostic
for i in $(seq 0 $((n_principles - 1))); do
  pname="${PRINCIPLE_NAMES[$i]}"
  qidx=$((i % n_questions))
  question="${PRINCIPLE_TO_QUESTION[$qidx]}"
  echo "──────────────────────────────────────────────────────────────"
  echo "Principle $((i+1)): $pname"
  echo "Diagnostic question for second project:"
  echo "  $question"
  echo ""
  echo "If Yes  → principle transfers (Domain scope is appropriate)"
  echo "If NO   → principle is Project-specific; consider demoting scope to Project"
  echo ""
done

echo "──────────────────────────────────────────────────────────────"
echo "What to do with results"
echo "──────────────────────────────────────────────────────────────"
echo ""
echo "1. **First-project verification**: For each principle, the answer to its diagnostic"
echo "   should be YES (because we know the principles work in this project). If any"
echo "   is NO, the principle may be miscategorized."
echo ""
echo "2. **Future project**: Before applying principles to a new project, ask the"
echo "   same diagnostic questions. If all are YES, the principles are likely to"
echo "   apply. If any is NO, skip that principle OR weaken the claim."
echo ""
echo "3. **Scope demotion**: If a principle's diagnostic is NO across multiple"
echo "   projects, demote from Domain → Project in the metadata block."
echo ""
echo "4. **No execution needed**: This script is a THINKING tool. It does not"
echo "   require running a second project. Just reason about the questions."
echo ""
echo "Validation log (run this on a real second project, document answer):"
echo ""
echo "  | Principle | This project? | Project 2? | Project 3? |"
echo "  |-----------|---------------|------------|------------|"
echo "  | Principle 1 | ? | ? | ? |"
echo "  | Principle 2 | ? | ? | ? |"
echo "  | ... | | | |"
echo ""
echo "When 2+ projects validate, the principles' scope can be confirmed as Domain."
echo "Until then, treat Domain as 'aspirational' and Project as 'realistic'."
echo ""
echo "──────────────────────────────────────────────────────────────"
echo "M3 Evidence Anchoring Reminder"
echo "──────────────────────────────────────────────────────────────"
echo ""
echo "All principles currently have evidence_count: 1 (this project only)."
echo "Per M3, a principle without concrete evidence is an unfalsifiable belief."
echo "Run this diagnostic on 2 more real projects before promoting these to Merged."
echo "Without that evidence, they should stay at status: TestsPass (not StableNoRevert)."
