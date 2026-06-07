#!/bin/bash
# propagate.sh — Cross-principle Bellman propagation
# Adapted from tempera's multi-hop Bellman mechanism
# (https://github.com/anvanster/tempera)
#
# Builds a graph where each principle is a node, edges connect principles
# that share evidence (via bellman_neighbours field). Computes utility
# via multi-hop Bellman updates:
#
#   utility(p) = direct_evidence(p) + γ × Σ_q (utility(q) × shared(q,p) / deg(q))
#
# where:
#   - direct_evidence: in-project evidence count (the "reward")
#   - γ: discount factor (default 0.3)
#   - shared(q,p): 1 if p lists q in bellman_neighbours
#   - deg(q): number of neighbours of q
#
# Outputs:
#   - Per-principle bellman_utility
#   - Propagation graph (which principles reinforce which)
#   - Suggested status upgrades (if utility crosses threshold)

set -e

PRINCIPLES_DIR="$(cd "$(dirname "$0")" && pwd)"
GAMMA="${BELLMAN_GAMMA:-0.3}"
ITERATIONS="${BELLMAN_ITERATIONS:-3}"

python3 - "$PRINCIPLES_DIR" "$GAMMA" "$ITERATIONS" <<'PYEOF'
import re
import sys
from pathlib import Path

principles_dir = Path(sys.argv[1])
gamma = float(sys.argv[2])
iterations = int(sys.argv[3])

# Parse all principle metadata blocks
principles = []  # list of dicts: {id, file, label, evidence, neighbours}

def split_principles(filepath):
    content = filepath.read_text()
    parts = re.split(r'\n(?=## (?:Principle|principle))', content)
    result = []
    for part in parts:
        if not part.strip():
            continue
        first_line = part.split('\n', 1)[0].strip()
        if not re.match(r'^##\s+(Principle|principle)', first_line):
            continue
        label = re.sub(r'^#+\s*', '', first_line).strip()
        result.append((label, part))
    return result or [("Whole file", content)]

for f in sorted(principles_dir.glob("*.md")):
    if f.name in ("README.md",):
        continue
    for label, text in split_principles(f):
        # Skip 16-principles.md (it doesn't have our metadata schema)
        if f.name == "16-principles.md":
            continue
        # Find principle-metadata block
        m = re.search(r'<!--\s*principle-metadata\s*\n(.*?)-->', text, re.DOTALL)
        if not m:
            continue
        meta = m.group(1)
        # Parse fields
        ev = 0
        neighbours = []
        for line in meta.strip().split('\n'):
            line = line.strip()
            if line.startswith('evidence_count:'):
                try:
                    ev = int(line.split(':', 1)[1].strip())
                except ValueError:
                    ev = 0
            elif line.startswith('bellman_neighbours:'):
                val = line.split(':', 1)[1].strip()
                # Strip [ ] and split by comma
                val = val.strip('[]')
                neighbours = [n.strip() for n in val.split(',') if n.strip()]
        # Extract principle ID from label (e.g., "Principle 1: The Proxy Paradox")
        pid_match = re.search(r'Principle\s+(\d+)', label)
        pid = pid_match.group(1) if pid_match else "?"
        # Use slug of label for cross-reference
        slug = re.sub(r'[^a-z0-9]+', '-', label.lower()).strip('-')[:30]
        principles.append({
            'id': pid,
            'file': f.name,
            'label': label,
            'evidence': ev,
            'neighbours': neighbours,
            'slug': slug,
        })

if len(principles) < 2:
    print(f"Need ≥ 2 principles to propagate. Found: {len(principles)}")
    sys.exit(0)

# Build graph
n = len(principles)
# Edge weight: 1 if i lists j in neighbours (directional, but we sum symmetric)
# For Bellman, treat edges as undirected: if i→j or j→i, there's a connection
# Bellman utility(p) flows from all neighbours of p

# Build adjacency: for each principle i, list of neighbours
def label_matches(neighbour_str, target):
    """Match neighbour string to a principle label. Use partial match."""
    n_norm = re.sub(r'[^a-z0-9]+', '-', neighbour_str.lower()).strip('-')[:30]
    t = target.lower()
    return n_norm in t or any(part in t for part in n_norm.split('-') if len(part) > 3)

adjacency = {i: set() for i in range(n)}
for i, p in enumerate(principles):
    for nb in p['neighbours']:
        for j, q in enumerate(principles):
            if i != j and label_matches(nb, q['label']):
                adjacency[i].add(j)

# Initialize utility with direct evidence
utility = [p['evidence'] for p in principles]
hop_contributions = [{j: 0 for j in range(n)} for i in range(n)]  # hop_contributions[i][j] = how much utility i got from j

print(f"=== Bellman Cross-Principle Propagation (multi-hop) ===")
print(f"Gamma: {gamma} | Max hops: {iterations}")
print(f"Principles: {n}")
print()

# True multi-hop Bellman: each iteration propagates the *new* utility
# utility_h[i][k] = utility of principle i at hop k (so we can apply discount per hop)
saturation_detected = False
prev_total = 0

# Direct evidence is hop 0 (no discount)
hop_utility = [principles[i]['evidence'] for i in range(n)]

for it in range(iterations):
    new_hop_utility = list(hop_utility)  # start with what we already have
    # Hop (it+1): each principle's neighbours contribute
    for i in range(n):
        for j in adjacency[i]:
            deg_j = len(adjacency[j]) if len(adjacency[j]) > 0 else 1
            # Discount by hop number (it+1)
            hop_num = it + 1
            discount = gamma ** hop_num
            contribution = hop_utility[j] / deg_j * discount
            new_hop_utility[i] += contribution
            hop_contributions[i][j] += contribution
    hop_utility = new_hop_utility
    # Final utility is the cumulative across all hops
    utility = list(hop_utility)
    # Check for saturation (compared to previous iteration's cumulative)
    total = sum(utility)
    if abs(total - prev_total) < 0.01 and it > 0:
        saturation_detected = True
        break
    prev_total = total

# Print results
print(f"{'Principle':<50}  {'Direct':>7}  {'Bellman':>8}  {'Total':>6}  Status hint")
print("-" * 100)
for i, p in enumerate(principles):
    direct = p['evidence']
    bellman = utility[i] - direct
    total = utility[i]
    if total >= 2.0:
        hint = "📈 Merged candidate"
    elif total >= 1.5:
        hint = "✓ Solidly TestsPass"
    elif total >= 1.0:
        hint = "  TestsPass"
    else:
        hint = "  weak"
    label_short = p['label'][:48]
    print(f"{label_short:<50}  {direct:>7}  {bellman:>8.2f}  {total:>6.2f}  {hint}")

print()
print("Interpretation:")
print("  Direct  = in-project evidence (evidence_count field)")
print("  Bellman = utility flowing in from neighbour principles (γ-discounted)")
print("  Total   = combined support strength")
print()
print("  Total > Direct × 1.5: principle benefits significantly from neighbours")
print("  Bellman = 0: principle is isolated (no shared evidence with others)")

# Multi-hop trace: which principle contributes how much to which
print()
print("=== Multi-Hop Contribution Matrix (who gives to whom) ===")
print()
# Show only non-zero contributions
contributions = []
for i in range(n):
    for j in range(n):
        if i != j and hop_contributions[i][j] > 0.001:
            contributions.append((i, j, hop_contributions[i][j]))

if contributions:
    contributions.sort(key=lambda x: -x[2])
    print(f"  {'From':<30} → {'To':<30}  Contribution")
    print("  " + "-" * 80)
    for i, j, c in contributions[:15]:  # top 15
        from_short = principles[i]['label'][:28]
        to_short = principles[j]['label'][:28]
        print(f"  {from_short:<30} → {to_short:<30}  {c:6.3f}")
    if len(contributions) > 15:
        print(f"  ... and {len(contributions) - 15} more")
else:
    print("  No multi-hop contributions (principles are isolated).")

# Show graph
print()
print("=== Propagation Graph ===")
for i, p in enumerate(principles):
    if adjacency[i]:
        nb_labels = [principles[j]['label'][:30] for j in adjacency[i]]
        print(f"  {p['label'][:30]}")
        for nb_label in nb_labels:
            print(f"    └─→ {nb_label}")
    else:
        print(f"  {p['label'][:30]}  (no neighbours)")

# Saturation detection
print()
print("=== Saturation Status ===")
if saturation_detected:
    print(f"  ✅ Saturated at iteration {it + 1}: graph reached fixed point (Δ < 0.01)")
    print(f"  Further iterations add no value. Bellman utility is converged.")
else:
    print(f"  ⏳ Not yet saturated after {iterations} iterations (Δ ≥ 0.01)")
    print(f"  Try: BELLMAN_ITERATIONS=10 bash propagate.sh for deeper propagation")
print()

# Heuristic suggestions
print("=== Suggestions ===")
for i, p in enumerate(principles):
    if utility[i] >= 2.0 and p['evidence'] < 2:
        print(f"  📈 Consider status upgrade to Merged: {p['label']} (utility={utility[i]:.2f})")
    if utility[i] < 1.0 and p['evidence'] == 0:
        print(f"  ⚠️  Weak: {p['label']} (utility={utility[i]:.2f}) — needs more direct evidence")

# Show what % of utility came from neighbours (vs direct)
print()
print("=== Direct vs Bellman Composition ===")
for i, p in enumerate(principles):
    direct = p['evidence']
    bellman = utility[i] - direct
    total = utility[i]
    if total > 0:
        d_pct = 100 * direct / total
        b_pct = 100 * bellman / total
        print(f"  {p['label'][:40]:<40}  {d_pct:5.1f}% direct  +  {b_pct:5.1f}% Bellman")
PYEOF
