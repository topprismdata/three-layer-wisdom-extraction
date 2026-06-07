#!/bin/bash
# check_stale.sh — Scope-aware principle decay checker
# Adapted from tempera's ValidityScope + decay mechanism
# (https://github.com/anvanster/tempera)
#
# For each principle in memory/principles/*.md, parse the
# principle-metadata block, compute days since last_validated,
# and flag principles that have exceeded their scope-based TTL.
#
# Scope decay rules (from tempera):
#   Forever    -> never expires
#   Language   -> 1095 days (3 years)
#   Domain     -> 365 days (1 year)
#   Crate      -> 180 days
#   Workaround -> 90 days
#   Project    -> 70 days
#
# Status: Untested (skip), TestsPass/Merged/StableNoRevert (check decay)

set -e

PRINCIPLES_DIR="$(cd "$(dirname "$0")" && pwd)"
TODAY_EPOCH=$(date +%s)

# Default decay days by scope
default_decay() {
  case "$1" in
    Forever)    echo 999999 ;;
    Language)   echo 1095 ;;
    Domain)     echo 365 ;;
    Crate)      echo 180 ;;
    Workaround) echo 90 ;;
    Project)    echo 70 ;;
    *)          echo 365 ;;
  esac
}

# Extract metadata for all principle blocks in a file, prints N TSV lines (one per block)
extract_metadata() {
  local f="$1"
  local in_block=0
  local status="" scope="" decay="" last_val=""
  local block_num=0
  local fname
  fname=$(basename "$f")

  while IFS= read -r line; do
    if [[ "$line" == *"<!-- principle-metadata"* ]]; then
      # Start new block (reset)
      in_block=1
      status="" scope="" decay="" last_val=""
      declared="" verified="" calibration=""
      block_num=$((block_num + 1))
      continue
    fi
    if [[ "$in_block" == "1" && "$line" == *"-->"* ]]; then
      # End of block: emit (including calibration data)
      in_block=0
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$fname" "$status" "$scope" "$decay" "$last_val" \
        "$declared" "$verified" "$calibration"
      continue
    fi
    if [[ "$in_block" == "1" ]]; then
      line="${line#${line%%[![:space:]]*}}"
      if [[ "$line" == *:* ]]; then
        local key="${line%%:*}"
        local val="${line#*:}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        case "$key" in
          status)             status="$val" ;;
          scope)              scope="$val" ;;
          decay_days)         decay="$val" ;;
          last_validated)     last_val="$val" ;;
          declared_success)   declared="$val" ;;
          verified_actual)    verified="$val" ;;
          calibration)        calibration="$val" ;;
        esac
      fi
    fi
  done < "$f"
}

# Convert YYYY-MM-DD to epoch
date_to_epoch() {
  date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null || echo 0
}

# Counters
healthy=0
fading=0
untested=0
skipped=0
fading_list=()

echo "=== Principle Decay Check ==="
echo "Today: $(date +%Y-%m-%d)"
echo ""

for f in "$PRINCIPLES_DIR"/*.md; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  [ "$fname" = "README.md" ] && continue
  [ "$fname" = "16-principles.md" ] && continue  # upstream, not our principles

  # Collect all metadata blocks for this file
  meta_lines=$(extract_metadata "$f")

  if [ -z "$meta_lines" ]; then
    echo "  ⏭  SKIP: $fname (no metadata)"
    skipped=$((skipped + 1))
    continue
  fi

  # Process each line (one per principle block)
  # Fields: fname status scope decay last_val declared verified calibration
  while IFS=$'\t' read -r f_name status scope decay last_val declared verified calibration; do
    [ -z "$status" ] && continue
    [ -z "$scope" ] && continue
    [ -z "$last_val" ] && continue

    if [ "$status" = "Untested" ]; then
      echo "  🔬 UNTESTED: $fname / $scope ($last_val)"
      untested=$((untested + 1))
      continue
    fi

    # Use default decay if not specified
    if [ -z "$decay" ]; then
      decay=$(default_decay "$scope")
    fi

    last_epoch=$(date_to_epoch "$last_val")
    if [ "$last_epoch" = "0" ]; then
      echo "  ❌ BAD_DATE: $fname / $scope ($last_val)"
      skipped=$((skipped + 1))
      continue
    fi

    age_days=$(( (TODAY_EPOCH - last_epoch) / 86400 ))
    remaining=$(( decay - age_days ))

    # Calibration check
    cal_warn=""
    if [ -n "$calibration" ] && [ -n "$verified" ]; then
      # Re-derive calibration from declared/verified (source of truth)
      computed_cal=$(awk -v d="$declared" -v v="$verified" 'BEGIN {
        if (d == "" || d+0 == 0) { print "n/a"; exit }
        printf "%.2f", v/d
      }')
      # Compare to declared calibration
      drift=$(awk -v a="$computed_cal" -v b="$calibration" 'BEGIN {
        diff = a+0 - b+0; if (diff < 0) diff = -diff; printf "%.2f", diff
      }')
      if [ "$computed_cal" != "$calibration" ] && [ "$(awk -v d="$drift" 'BEGIN { print (d+0 > 0.05) ? 1 : 0 }')" = "1" ]; then
        cal_warn=" ⚠️  CAL_DRIFT(declared=${calibration}, computed=${computed_cal})"
      fi
      if [ -n "$computed_cal" ] && [ "$computed_cal" != "n/a" ]; then
        if [ "$(awk -v c="$computed_cal" 'BEGIN { print (c+0 < 0.5) ? 1 : 0 }')" = "1" ]; then
          cal_warn="${cal_warn} 🚨 OVERCONFIDENT(<0.5)"
        fi
      fi
    fi

    if [ "$age_days" -gt "$decay" ]; then
      echo "  ⚠️  FADING: $fname / $scope (age=${age_days}d, decay=${decay}d)${cal_warn}"
      fading_list+=("$fname / $scope")
      fading=$((fading + 1))
    else
      cal_info=""
      if [ -n "$declared" ] && [ -n "$verified" ]; then
        cal_info=" cal=${computed_cal:-n/a} (${verified}/${declared} verified)"
      fi
      echo "  ✅ OK: $fname / $scope (age=${age_days}d, remaining=${remaining}d)${cal_info}${cal_warn}"
      healthy=$((healthy + 1))
    fi
  done <<< "$meta_lines"
done

echo ""
echo "=== Summary ==="
echo "  Healthy:   $healthy"
echo "  Fading:    $fading"
echo "  Untested:  $untested"
echo "  Skipped:   $skipped"

if [ "$fading" -gt 0 ]; then
  echo ""
  echo "Action: review FADING principles:"
  for p in "${fading_list[@]}"; do
    echo "  - $p: revalidate (update last_validated) or DEPRECATE (set status=Deprecated)"
  done
fi
