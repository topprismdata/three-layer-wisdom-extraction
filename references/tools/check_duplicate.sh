#!/bin/bash
# check_duplicate.sh — Find similar principles (HaluMem-style dedup)
# Adapted from tempera's HaluMem benchmark for hallucination detection
# (https://github.com/MemTensor/HaluMem)
#
# Splits each .md file by "## Principle N" headers so that 4 principles
# in one file are compared against each other AND against principles in
# other files. Uses Jaccard word-overlap as the similarity metric.

set -e

PRINCIPLES_DIR="$(cd "$(dirname "$0")" && pwd)"
THRESHOLD="${DEDUP_THRESHOLD:-0.4}"
TOP_N="${DEDUP_TOP_N:-5}"

python3 - "$PRINCIPLES_DIR" "$THRESHOLD" "$TOP_N" <<'PYEOF'
import os
import re
import sys
from pathlib import Path
from itertools import combinations

principles_dir = Path(sys.argv[1])
threshold = float(sys.argv[2])
top_n = int(sys.argv[3])

# Stopwords for filtering
STOP = set("""this that with from which have been will would could should these those there
where when what such only than then some also into over more most other very much each
every both either neither after before under above below because while though although
since unless until whereas whenever wherever whether however moreover furthermore
nevertheless nonetheless meanwhile therefore thus hence accordingly consequently
otherwise instead rather quite almost nearly just still already yet soon here they them
their our your my his her its ours yours theirs hers mine self themselves ourselves
itself about because being doing during have having into once per same than very was
were being doing across among around before during except off out through toward upon
within without""".split())

def extract_words(text):
    """Extract significant words (lowercase, len>=4, not stopword)."""
    text = text.lower()
    # Remove HTML-ish comments
    text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
    # Remove headers
    text = re.sub(r'^#.*$', '', text, flags=re.MULTILINE)
    words = re.findall(r'\b[a-z][a-z_-]{3,}\b', text)
    return set(w for w in words if w not in STOP)

def split_principles(filepath):
    """Split a markdown file by '## Principle' headers. Returns list of (label, text)."""
    content = filepath.read_text()
    # Find all "## Principle N: ..." headers
    parts = re.split(r'\n(?=## (?:Principle|principle))', content)
    principles = []
    for part in parts:
        if not part.strip():
            continue
        # First line must actually be a "## Principle" header (skip intro)
        first_line = part.split('\n', 1)[0].strip()
        if not re.match(r'^##\s+(Principle|principle)', first_line):
            continue
        label = re.sub(r'^#+\s*', '', first_line).strip()
        text = part
        principles.append((label, text))
    if not principles:
        # Whole file as one principle
        principles = [("Whole file", content)]
    return principles

# Collect all principles
principles = []
for f in sorted(principles_dir.glob("*.md")):
    if f.name == "README.md":
        continue
    for label, text in split_principles(f):
        words = extract_words(text)
        if len(words) < 3:
            continue
        principles.append({
            "file": f.name,
            "label": label,
            "words": words,
        })

print(f"=== Principle Duplicate Check ===")
print(f"Threshold (Jaccard): {threshold}")
print(f"Principles found: {len(principles)}")
print()

def jaccard(a, b):
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0

# Find all pairs above threshold
pairs = []
for p1, p2 in combinations(principles, 2):
    j = jaccard(p1["words"], p2["words"])
    if j >= threshold:
        pairs.append((j, p1, p2))

# Sort by Jaccard desc
pairs.sort(key=lambda x: -x[0])

if not pairs:
    print(f"✅ No duplicate pairs found at threshold {threshold}.")
    print(f"   (Total pairs checked: {len(list(combinations(principles, 2)))} — all below threshold)")
    print()
    print("If you suspect duplicates, lower DEDUP_THRESHOLD (e.g. 0.25).")
else:
    print(f"Top similar pairs (Jaccard ≥ {threshold}):")
    print()
    for j, p1, p2 in pairs[:top_n]:
        print(f"  {j:.3f} | {p1['file']}: {p1['label']}")
        print(f"        ↕")
        print(f"  {j:.3f} | {p2['file']}: {p2['label']}")
        # Show 5 shared words
        shared = sorted(p1["words"] & p2["words"])[:5]
        if shared:
            print(f"        Shared words: {', '.join(shared)}")
        print()
    if len(pairs) > top_n:
        print(f"... and {len(pairs) - top_n} more (increase DEDUP_TOP_N to see all)")

print()
print(f"=== Summary ===")
print(f"  Pairs ≥ {threshold}: {len(pairs)}")
print(f"  (DEDUP_THRESHOLD={threshold}, DEDUP_TOP_N={top_n})")

if pairs:
    print()
    print("Action: review pairs above. If two principles cover the same idea,")
    print("        consolidate into one (keep the one with more evidence).")
PYEOF
