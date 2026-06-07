#!/bin/bash
# multi_actor_extract.sh — Run 3 independent Layer 3 extractions with different
# personas, then synthesize a consensus set.
# Implements Principle M1 (Single-Actor Bias) from meta-extraction.md.
#
# Usage: bash multi_actor_extract.sh <input_file>
#   <input_file> should be a Layer 1 timeline (what was tried, what happened)
#   or a Layer 2 insight list
#
# Output: a synthesized principle set with attribution to each actor
#
# Requires: mmx CLI (https://github.com/MiniMax-AI/cli)

set -e

if [ -z "$1" ] || [ ! -f "$1" ]; then
  echo "Usage: bash multi_actor_extract.sh <input_file>"
  echo "  <input_file>: Layer 1 timeline or Layer 2 insight list"
  exit 1
fi

INPUT_FILE="$1"
MAX_TOKENS="${MULTI_ACTOR_MAX_TOKENS:-2048}"
TEMPERATURE="${MULTI_ACTOR_TEMP:-0.7}"
MODEL="${MULTI_ACTOR_MODEL:-MiniMax-M2.7}"

INPUT_CONTENT=$(cat "$INPUT_FILE")
WORD_COUNT=$(echo "$INPUT_CONTENT" | wc -w | tr -d ' ')

echo "=== Multi-Actor Layer 3 Extraction (Principle M1) ==="
echo "Input: $INPUT_FILE ($WORD_COUNT words)"
echo "Model: $MODEL"
echo "Temperature: $TEMPERATURE"
echo "Max tokens: $MAX_TOKENS"
echo ""

# Common prompt template
EXTRACTION_PROMPT="You are analyzing a sequence of events from an ML/data-science project. Apply the three-layer wisdom extraction technique to identify 3-7 UNIVERSAL Layer 3 principles (not domain-specific tactics, but patterns that transfer to other domains).

For each principle, output:
- NAME: short memorable name (5 words or fewer)
- ONE-LINE: single-sentence statement
- WHY-IT-TRANSFERS: brief explanation (1 sentence)
- DOMAINS: at least 2 other domains where it applies
- EVIDENCE: specific experiment from the input that supports it
- CANNOT-CATCH: 2-3 failure modes this principle does NOT cover

Use the 5-question abstraction (INVERSION / GENERALIZATION / TRANSFER / PARADOX / META) before writing each principle. Apply multi-perspective analysis (Pragmatist / Skeptic / Cross-domain) as a final filter.

Here is the input to analyze:

$INPUT_CONTENT

Output ONLY the principles (no preamble, no closing commentary)."

# Three actor personas
PERSONA_EMPIRICIST="You are a strict empiricist data scientist. You only believe in principles backed by direct experimental evidence. Reject any principle that is too abstract to falsify. Prefer principles that cite specific experiments from the input. Be skeptical of 'wisdom' that sounds nice but has no data."

PERSONA_THEORETICIAN="You are a theoretician who studies causal mechanisms. You look for WHY things work, not just THAT they work. Prefer principles that explain a mechanism, not just describe a pattern. Reject any principle that is pure correlation without causal story. Look for hidden variables."

PERSONA_PRAGMATIST="You are a pragmatic ML engineer shipping production models. You value principles that change decisions. Reject any principle that is intellectually interesting but doesn't tell you what to do differently. Prefer principles that have a clear 'action' clause. Skip principles that just describe a phenomenon without prescribing a response."

# Run all 3 actors in parallel
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Running 3 actors in parallel..."
echo ""

run_actor() {
  local actor="$1"
  local persona="$2"
  echo "  $actor starting..." >&2
  # Use --output json to get full API response, then extract text in Python
  result=$(mmx text chat \
    --model "$MODEL" \
    --system "$persona" \
    --message "$EXTRACTION_PROMPT" \
    --max-tokens "$MAX_TOKENS" \
    --temperature "$TEMPERATURE" \
    --no-stream \
    --output json 2>/dev/null)
  echo "$result" > "$TMPDIR/actor_$actor.json"
  # Quick word count on raw (will be re-counted in Python after extraction)
  word_n=$(echo "$result" | wc -w | tr -d ' ')
  echo "  $actor: $word_n raw chars received" >&2
}

run_actor "empiricist" "$PERSONA_EMPIRICIST" &
run_actor "theoretician" "$PERSONA_THEORETICIAN" &
run_actor "pragmatist" "$PERSONA_PRAGMATIST" &
wait

echo ""
echo "=== Per-Actor Results ==="
echo ""

for actor in empiricist theoretician pragmatist; do
  if [ -f "$TMPDIR/actor_$actor.json" ]; then
    # Extract text from JSON using here-doc (avoids shell quoting issues)
    text=$(python3 - "$TMPDIR/actor_$actor.json" <<'PYEOF'
import json, sys
def extract_text(obj):
    if isinstance(obj, str):
        return obj
    if isinstance(obj, list):
        parts = []
        for item in obj:
            if isinstance(item, dict):
                if item.get('type') == 'thinking':
                    continue
                t = item.get('text', '')
                if isinstance(t, str) and t:
                    parts.append(t)
        if parts:
            return "\n".join(parts)
        return ""
    if isinstance(obj, dict):
        if 'content' in obj:
            t = extract_text(obj['content'])
            if t:
                return t
        if 'choices' in obj:
            for c in obj['choices']:
                t = extract_text(c)
                if t:
                    return t
        for k in ('text',):
            if k in obj and isinstance(obj[k], str):
                return obj[k]
        return ""
    return ""

try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    result = extract_text(d)
    if result:
        print(result)
    else:
        print('[could not extract text]')
except Exception as e:
    print(f'[error: {e}]')
PYEOF
)
    echo "$text" > "$TMPDIR/actor_$actor.txt"
    word_n=$(echo "$text" | wc -w | tr -d ' ')
    echo "--- $actor ($word_n words) ---"
    echo "$text" | head -20
    echo "..."
    echo ""
  fi
done

# Synthesis: extract principle names from each actor's output
echo "=== Synthesis ==="
echo ""

python3 - "$TMPDIR" <<'PYEOF'
import re
import sys
from pathlib import Path
from collections import defaultdict

tmpdir = Path(sys.argv[1])

# Extract principle names from each actor's output
# Heuristic: lines starting with "NAME:" or lines that look like "## Principle Name"
principles_by_actor = defaultdict(list)
all_principles = {}  # name -> set of actors

for actor in ("empiricist", "theoretician", "pragmatist"):
    f = tmpdir / f"actor_{actor}.txt"
    if not f.exists():
        continue
    text = f.read_text()
    # Try to find NAME: lines (e.g., "1. **NAME:** Foo")
    name_pattern = re.compile(r'(?:^|\n)\s*(?:\d+\.\s*)?\*?\*?NAME\*?\*?:\s*\*?\*?([^\n]+)', re.IGNORECASE)
    for m in name_pattern.finditer(text):
        name = m.group(1).strip().rstrip('.').strip().rstrip('*').strip()
        if 3 < len(name) < 80:
            principles_by_actor[actor].append(name)
            all_principles.setdefault(name.lower(), set()).add(actor)
    # If no NAME: lines, try to find ## headers
    if not principles_by_actor[actor]:
        h_pattern = re.compile(r'(?:^|\n)##\s+(.+?)(?:\n|$)')
        for m in h_pattern.finditer(text):
            name = m.group(1).strip()
            if 3 < len(name) < 80 and not name.startswith("Domain"):
                principles_by_actor[actor].append(name)
                all_principles.setdefault(name.lower(), set()).add(actor)

# Build consensus matrix
print("Consensus matrix (which actor proposed which principle):")
print()
print(f"{'Principle':<60} | empiricist | theoretician | pragmatist | Score")
print("-" * 100)

# Deduplicate by lowercase
seen = set()
sorted_principles = []
for name_lower, actors in all_principles.items():
    if name_lower in seen:
        continue
    seen.add(name_lower)
    # Get a display name (any of the actors' names for this principle)
    display_name = None
    for actor in ("empiricist", "theoretician", "pragmatist"):
        for n in principles_by_actor[actor]:
            if n.lower() == name_lower:
                display_name = n
                break
        if display_name:
            break
    if not display_name:
        display_name = name_lower
    sorted_principles.append((display_name, actors))

# Sort by number of actors (consensus first)
sorted_principles.sort(key=lambda x: -len(x[1]))

for name, actors in sorted_principles:
    short = name[:58] + ".." if len(name) > 60 else name
    e = "✓" if "empiricist" in actors else " "
    t = "✓" if "theoretician" in actors else " "
    p = "✓" if "pragmatist" in actors else " "
    score = len(actors)
    print(f"{short:<60} |     {e}      |      {t}      |     {p}      |   {score}/3")

print()
# Categorize
strong = [(n, a) for n, a in sorted_principles if len(a) == 3]
medium = [(n, a) for n, a in sorted_principles if len(a) == 2]
weak = [(n, a) for n, a in sorted_principles if len(a) == 1]

print(f"=== Recommendation ===")
print(f"  Strong consensus (3/3 actors): {len(strong)} principles → include verbatim")
print(f"  Medium consensus (2/3 actors): {len(medium)} principles → include with caveat")
print(f"  Weak consensus (1/3 actors): {len(weak)} principles → drop or mark Untested")
print()

if strong:
    print("Strong consensus principles (include as-is):")
    for name, _ in strong:
        print(f"  • {name}")
    print()

if medium:
    print("Medium consensus principles (include with caveat):")
    for name, actors in medium:
        missing = [a for a in ("empiricist", "theoretician", "pragmatist") if a not in actors]
        print(f"  • {name} (missing: {', '.join(missing)})")
    print()

if weak:
    print("Weak consensus (review and either drop or re-examine):")
    for name, _ in weak:
        print(f"  • {name}")

# Save synthesized output
synth = tmpdir / "synthesized.md"
with open(synth, "w") as f:
    f.write("# Multi-Actor Synthesized Principles\n\n")
    f.write(f"Generated by multi_actor_extract.sh on {Path('.').cwd()}\n\n")
    f.write("## Strong Consensus (3/3 actors)\n\n")
    for name, _ in strong:
        f.write(f"- {name}\n")
    f.write("\n## Medium Consensus (2/3 actors)\n\n")
    for name, actors in medium:
        missing = [a for a in ("empiricist", "theoretician", "pragmatist") if a not in actors]
        f.write(f"- {name} (missing: {', '.join(missing)})\n")
    f.write("\n## Weak Consensus (1/3 actors) — Review\n\n")
    for name, _ in weak:
        f.write(f"- {name}\n")
print(f"\nFull synthesis saved to: {synth}")
PYEOF

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Review strong consensus principles — these are robust"
echo "  2. Examine medium consensus — what did the disagreeing actor miss?"
echo "  3. Decide on weak consensus — drop or re-extract"
echo "  4. For accepted principles, add them to your principles/ file with metadata"
