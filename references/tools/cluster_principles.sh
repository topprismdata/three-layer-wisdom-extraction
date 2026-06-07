#!/bin/bash
# cluster_principles.sh — Reader-fatigue metric + auto-cluster
# Implements Principle M2 (Layer 3 Fatigue Ceiling) from meta-extraction.md.
#
# Computes total word count across all principles in memory/principles/*.md.
# If total > FATIGUE_THRESHOLD_WORDS, suggests clusters and proposes a
# "super-principle" merge of the most similar ones.
#
# Inspired by:
#   - "7±2 items" working memory limit (Miller 1956)
#   - Documentation principle: best docs are scannable in < 5 min
#
# Usage:
#   bash cluster_principles.sh                 # check current fatigue
#   bash cluster_principles.sh --auto-merge    # auto-merge similar pairs
#   FATIGUE_THRESHOLD_WORDS=8000 bash ...     # custom threshold

set -e

PRINCIPLES_DIR="$(cd "$(dirname "$0")" && pwd)"
THRESHOLD="${FATIGUE_THRESHOLD_WORDS:-11000}"  # ~ 11 KB prose
AUTO_MERGE="${1:-}"
APPLY_FLAG="${2:-}"
MIN_WORD_LIMIT=3   # ignore principles shorter than this (likely meta)
CLUSTER_METHOD="${CLUSTER_METHOD:-jaccard}"  # jaccard | co-occurrence

# Parse --apply flag
apply_split=0
if [ "$APPLY_FLAG" = "--apply" ]; then
  apply_split=1
fi

# Step 1: Parse all principles with metadata
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

for f in "$PRINCIPLES_DIR"/*.md; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  [ "$fname" = "README.md" ] && continue
  [ "$fname" = "16-principles.md" ] && continue

  # Use Python to split by ## Principle (more robust than awk)
  python3 - "$f" "$TMPDIR" <<'PYEOF'
import sys
from pathlib import Path

src = Path(sys.argv[1])
tmpdir = Path(sys.argv[2])
content = src.read_text()

# Split on lines that start with "## Principle"
import re
parts = re.split(r'\n(?=## (?:Principle|principle))', content)
n = 0
for part in parts:
    if not part.strip():
        continue
    first_line = part.split('\n', 1)[0]
    if not re.match(r'^##\s+(Principle|principle)', first_line):
        continue
    n += 1
    label = re.sub(r'^#+\s*', '', first_line).strip()
    (tmpdir / f"id_{n}").write_text(f"{src.name}\t{label}\n")
    (tmpdir / f"p_{n}").write_text(part)
PYEOF
done

# Step 2: Compute word counts per principle
echo "=== Reader-Fatigue Metric (Principle M2) ==="
echo "Threshold: $THRESHOLD words"
echo ""

total_words=0
total_principles=0
total_principles=$(( $(ls "$TMPDIR"/id_* 2>/dev/null | wc -l | tr -d ' ') ))
if [ "$total_principles" -lt 1 ]; then
  echo "No principles found in $PRINCIPLES_DIR"
  exit 0
fi

# Build per-principle stats
printf "%-50s  %6s  %6s  %s\n" "Principle" "Words" "Bytes" "Status"
printf "%-50s  %6s  %6s  %s\n" "$(printf '%.0s-' {1..50})" "-----" "-----" "------"

for id_file in "$TMPDIR"/id_*; do
  [ -f "$id_file" ] || continue
  IFS=$'\t' read -r fname label < "$id_file"
  n=$(basename "$id_file" | sed 's/id_//')
  content_file="$TMPDIR/p_$n"
  [ -f "$content_file" ] || continue

  # Strip metadata blocks and headers
  body=$(awk '
    /^<!--/ { skip=1; next }
    /-->/ && skip { skip=0; next }
    /^#/ { next }
    !skip { print }
  ' "$content_file")

  words=$(echo "$body" | wc -w | tr -d ' ')
  bytes=$(echo "$body" | wc -c | tr -d ' ')

  # Skip if too small (metadata-only blocks)
  if [ "$words" -lt "$MIN_WORD_LIMIT" ]; then
    continue
  fi

  total_words=$((total_words + words))
  total_bytes=$((total_bytes + bytes))

  status="OK"
  if [ "$words" -gt 3000 ]; then
    status="⚠️  CHONKY (>3000 words)"
  fi

  short_label=$(echo "$label" | cut -c1-48)
  printf "%-50s  %6d  %6d  %s\n" "$short_label" "$words" "$bytes" "$status"
done

# Step 3: Report
echo ""
echo "=== Fatigue Assessment ==="
echo "Total principles: $total_principles"
echo "Total words:      $total_words"
echo "Total bytes:      $total_bytes (~$((total_bytes / 1024)) KB)"
echo "Threshold:        $THRESHOLD words (~$((THRESHOLD / 1000)) KB)"
echo ""

if [ "$total_words" -gt "$THRESHOLD" ]; then
  echo "🚨 FATIGUE WARNING: Total exceeds threshold"
  echo "  Reader retention drops sharply beyond ~5K words."
  echo "  Recommendation: Cluster principles into super-principles."
  echo ""
  echo "Auto-suggested clusters (by topic similarity):"
  echo ""
fi

# Step 4: Auto-cluster (Jaccard similarity threshold)
echo "=== Suggested Cluster Actions ==="
echo ""

# Build a simple TF (term frequency) per principle, excluding stopwords
PRINCIPLES_DIR="$PRINCIPLES_DIR" python3 - "$TMPDIR" "$THRESHOLD" "$AUTO_MERGE" "$apply_split" <<'PYEOF'
import re
import sys
import os
from pathlib import Path
from itertools import combinations

tmpdir = Path(sys.argv[1])
threshold = int(sys.argv[2])
auto_merge = sys.argv[3] if len(sys.argv) > 3 else ""
apply_split = int(sys.argv[4]) if len(sys.argv) > 4 else 0

STOP = set("""this that with from which have been will would could should these those there
where when what such only than then some also into over more most other very much each
every both either neither after before under above below because while though although
since unless until whereas whenever wherever whether however moreover furthermore
nevertheless nonetheless meanwhile therefore thus hence accordingly consequently
otherwise instead rather quite almost nearly just still already yet soon here they them
their our your my his her its ours yours theirs hers mine self themselves ourselves
itself about because being doing during have having into once per same than very was
were being doing across among around before during except off out through toward upon
within without can will would could should may might must shall do does did done""".split())

# Collect all principles
principles = []
for id_file in sorted(tmpdir.glob("id_*")):
    n = id_file.name.split("_")[1]
    label = id_file.read_text().strip().split("\t")[1] if "\t" in id_file.read_text() else ""
    fname = id_file.read_text().strip().split("\t")[0]
    content_file = tmpdir / f"p_{n}"
    if not content_file.exists():
        continue
    body = content_file.read_text()
    # Skip metadata
    body = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
    body = re.sub(r"^#.*$", "", body, flags=re.MULTILINE)
    words = re.findall(r"\b[a-z][a-z_-]{3,}\b", body.lower())
    words = [w for w in words if w not in STOP]
    if len(words) < 10:
        continue
    principles.append({
        "file": fname,
        "label": label,
        "words": set(words),
    })

if len(principles) < 2:
    sys.exit(0)

# Find all similar pairs (Jaccard > threshold)
# Default 0.20, can override with CLUSTER_THRESHOLD env var
cluster_threshold = float(os.environ.get("CLUSTER_THRESHOLD", "0.20"))
pairs = []
for p1, p2 in combinations(principles, 2):
    if not p1["words"] or not p2["words"]:
        continue
    inter = len(p1["words"] & p2["words"])
    union = len(p1["words"] | p2["words"])
    j = inter / union if union else 0
    if j > cluster_threshold:
        pairs.append((j, p1, p2))

pairs.sort(key=lambda x: -x[0])

if not pairs:
    print("No clusters found (no Jaccard > 0.20 pairs).")
    print("Principles are well-differentiated; no auto-merge needed.")
else:
    print(f"Found {len(pairs)} similar pairs (Jaccard > 0.20):")
    print()
    for j, p1, p2 in pairs[:10]:
        shared = sorted(p1["words"] & p2["words"])[:5]
        print(f"  {j:.3f} | {p1['label'][:30]}")
        print(f"        ↕")
        print(f"        | {p2['label'][:30]}")
        print(f"        Shared: {', '.join(shared)}")
        print()

# Auto-split: if AUTO_SPLIT=1, propose a 2-way split
if auto_merge == "--auto-split":
    print()
    print("=== Auto-Cluster Proposal (agglomerative, N clusters) ===")
    print()
    # ---- Agglomerative clustering (single-linkage) ----
    # Start: each principle is its own cluster
    # At each step, merge the 2 clusters with the highest avg-link Jaccard
    # Stop when the highest Jaccard < split_threshold
    # Result: N clusters, where 1 ≤ N ≤ total
    # Note: this is a SEPARATE threshold from cluster_threshold (used for pair detection above)
    # Lower split_threshold → more clusters (less aggressive merging)
    split_threshold = float(os.environ.get("SPLIT_THRESHOLD", "0.18"))
    # ---- Agglomerative clustering (single-linkage) ----
    # Start: each principle is its own cluster
    # At each step, merge the 2 clusters with the highest avg-link Jaccard
    # Stop when the highest Jaccard < split_threshold
    # Result: N clusters, where 1 ≤ N ≤ total

    # Build label -> principle index map
    label_to_idx = {p["label"]: i for i, p in enumerate(principles)}

    # Initialize: each principle is its own cluster (label = its index)
    # Use list not set, because we do `clusters[i] + clusters[j]` later
    clusters = [[label_to_idx[p["label"]]] for p in principles]

    def jaccard(a_idx_set, b_idx_set):
        """Jaccard between two clusters, computed as average pairwise."""
        if not a_idx_set or not b_idx_set:
            return 0
        # Use union/intersection of words across all cluster members
        words_a = set()
        for i in a_idx_set:
            words_a |= principles[i]["words"]
        words_b = set()
        for i in b_idx_set:
            words_b |= principles[i]["words"]
        if not words_a or not words_b:
            return 0
        inter = len(words_a & words_b)
        union = len(words_a | words_b)
        return inter / union if union else 0

    # Iteratively merge
    merge_log = []
    while True:
        # Find the pair with highest Jaccard
        best_j = -1
        best_pair = None
        n_clusters = len(clusters)
        for i in range(n_clusters):
            for j in range(i + 1, n_clusters):
                j_val = jaccard(clusters[i], clusters[j])
                if j_val > best_j:
                    best_j = j_val
                    best_pair = (i, j)
        if best_pair is None or best_j < split_threshold:
            break
        # Merge the best pair
        i, j = best_pair
        merged = clusters[i] + clusters[j]
        # Remove the higher index first (to keep i valid)
        if i < j:
            clusters.pop(j)
            clusters[i] = merged
        else:
            clusters.pop(i)
            clusters[j] = merged
        merge_log.append((best_j, len(clusters[i])))
        if len(clusters) <= 1:
            break  # single cluster left, stop

    print(f"  Stopping threshold: Jaccard = {split_threshold}")
    print(f"  Initial: {len(principles)} principles as 1-element clusters")
    print(f"  Final: {len(clusters)} clusters after {len(merge_log)} merges")
    print()
    if len(clusters) == len(principles):
        print("  No merges possible (all pairs below threshold). Principles are well-differentiated.")
        print("  No need to split.")
    else:
        # Show cluster details
        for ci, cluster in enumerate(clusters):
            print(f"  Cluster {ci + 1} ({len(cluster)} principles):")
            for idx in cluster:
                short = principles[idx]["label"][:50]
                print(f"    • {short}")
            print()
        # Filenames
        print(f"  Suggested filenames:")
        for ci, cluster in enumerate(clusters):
            if cluster:
                slug = re.sub(r'[^a-z0-9]+', '-', principles[cluster[0]]["label"].lower()).strip('-')[:20]
                print(f"    cluster-{ci + 1}-{slug}.md  ({len(cluster)} principles)")
        print()

        if apply_split:
            # Actually create the files in the actual principles dir
            actual_principles_dir = os.environ.get("PRINCIPLES_DIR", ".")
            for ci, cluster in enumerate(clusters):
                if not cluster:
                    continue
                src_file = principles[cluster[0]]["file"]
                src_path = Path(actual_principles_dir) / src_file
                if not src_path.exists():
                    print(f"  ⚠️  Source not found: {src_path}, skipping cluster {ci + 1}")
                    continue
                slug = re.sub(r'[^a-z0-9]+', '-', principles[cluster[0]]["label"].lower()).strip('-')[:20]
                dst = Path(actual_principles_dir) / f"cluster-{ci + 1}-{slug}.md"
                print(f"  Writing: {dst}")
                with open(src_path) as f:
                    content = f.read()
                # Keep only principle sections in this cluster
                labels_in_cluster = set(principles[i]["label"] for i in cluster)
                sections = re.split(r'\n(?=## (?:Principle|principle))', content)
                kept = []
                kept.append(sections[0])  # preamble
                for sec in sections[1:]:
                    first = sec.split("\n", 1)[0]
                    if re.match(r'^##\s+(Principle|principle)', first):
                        label = re.sub(r'^#+\s*', '', first).strip()
                        if label in labels_in_cluster:
                            kept.append(sec)
                with open(dst, "w") as f:
                    f.write("\n".join(kept))
                print(f"    Wrote {len(kept) - 1} principles to {dst.name}")
            print()
            print("  ⚠️  MANUAL CLEANUP NEEDED:")
            print("    1. Review the new files")
            print("    2. Delete the original file once verified")
            print("    3. Update memory/MEMORY.md to add new file links")
            print("    4. Run check_stale.sh + propagate.sh to update indices")
        else:
            print()
            print("  To actually create these files, run with --apply:")
            print("    bash cluster_principles.sh --auto-split --apply")
            print()
            print("  Or with custom threshold (lower → more clusters):")
            print("    CLUSTER_THRESHOLD=0.10 bash cluster_principles.sh --auto-split")

# Compute total words
total_words = sum(len(re.findall(r"\b[a-z][a-z_-]{3,}\b", p['label'])) for p in principles)
# Just count from original (not words set)
PYEOF

echo ""
echo "=== Manual Recommendations ==="
echo ""
echo "1. **Read in chunks**: Split the file by '## Principle' headers and read one at a time."
echo "2. **Use metadata blocks**: Search by status (e.g., 'TestsPass') to filter relevant ones."
echo "3. **Tag with domain tags**: Add 'domain: ml/finance/...' to find principles by area."
echo "4. **Cluster by hand**: Group 2-3 related principles under a 'super-principle' section header."
echo "5. **Archive stale ones**: If a principle has FADING status, move to memory/archive/."
echo ""
echo "If the file still exceeds ~11K words after clustering, consider:"
echo "  - Splitting into multiple files by topic (e.g., ml-forecasting.md, ml-eval.md)"
echo "  - Keeping 'Core' in principles/ and moving 'Extended' to memory/extended/"
